// Package status provides a status page handler, for exposing a summary of what
// the various pieces of the agent are doing.
//
// Inspired heavily by Google "/statsuz" - one public example is at:
// https://github.com/youtube/doorman/blob/master/go/status/status.go
package status

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"maps"
	"net/http"
	"os"
	"os/user"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/defn/other/m/v/buildkite--agent/version"
)

const errorTmplSrc = `<div class="error">❌ {{.Operation}}: <code>{{.Error}}</code><br>
Raw item data:<br>
<pre>{{.Item | printJSON}}</pre>
</div>`

var (
	statusTmplSrc = statusTemplate

	// Errors ignored below, as the status page is "best effort".
	hostname, _ = os.Hostname()
	username    = func() string {
		user, err := user.Current()
		if err != nil {
			return fmt.Sprintf("unknown (uid=unknown; error=%v)", err)
		}
		return fmt.Sprintf("%s (uid=%s)", user.Username, user.Uid)
	}()
	exepath, _ = os.Executable()
	startTime  = time.Now()

	rootItem = &simpleItem{
		baseItem: baseItem{
			items: make(map[string]item),
		},
	}

	funcMap = template.FuncMap{
		"printJSON": printJSON,
	}

	// The inbuilt templates should always parse. Rather than use template.Must,
	// successful parsing is enforced by the smoke tests.
	statusTmpl, _ = template.New("status").Funcs(funcMap).Parse(statusTmplSrc)
	errorTmpl, _  = template.New("item-error").Funcs(funcMap).Parse(errorTmplSrc)
)

type statusData struct {
	Items        map[string]item
	Version      string
	Build        string
	Hostname     string
	Username     string
	ExePath      string
	PID          int
	Compiler     string
	RuntimeVer   string
	GOOS         string
	GOARCH       string
	NumCPU       int
	NumGoroutine int
	StartTime    string
	StartTimeAgo time.Duration
	CurrentTime  string
	Ctx          context.Context // request context for Eval calls inside the template execution only
}

type errorData struct {
	Operation string
	Error     error
	Item      any
}

type item interface {
	addSubItem(string, item)
	delSubItem(string)

	Eval(context.Context) template.HTML
	Items() map[string]item
}

type itemCtxKey struct{}

func parentItem(ctx context.Context) item {
	v := ctx.Value(itemCtxKey{})
	if v == nil {
		return rootItem
	}
	return v.(item)
}

type baseItem struct {
	mu    sync.RWMutex
	items map[string]item
}

func (i *baseItem) addSubItem(title string, sub item) {
	i.mu.Lock()
	defer i.mu.Unlock()
	i.items[title] = sub
}

func (i *baseItem) delSubItem(title string) {
	i.mu.Lock()
	defer i.mu.Unlock()
	delete(i.items, title)
}

func (i *baseItem) Items() map[string]item {
	i.mu.RLock()
	defer i.mu.RUnlock()
	return maps.Clone(i.items)
}

// SimpleItem is for untemplated status items that only report a simple non-HTML string.
type simpleItem struct {
	baseItem
	stat string
}

// SetStatus sets the status of the item.
func (i *simpleItem) setStatus(s string) {
	i.mu.Lock()
	defer i.mu.Unlock()
	i.stat = s
}

// Eval escapes the status string, and returns the current item value.
func (i *simpleItem) Eval(ctx context.Context) template.HTML {
	i.mu.RLock()
	defer i.mu.RUnlock()
	return template.HTML(template.HTMLEscapeString(i.stat))
}

// ItemCallback funcs are used by templated status items to provide the value to
// hydrate the item template.
type ItemCallback = func(context.Context) (any, error)

// templatedItem uses a template to format the item.
type templatedItem struct {
	baseItem
	tmpl *template.Template
	cb   ItemCallback
}

// Eval calls the item callback, and feeds the result through the item's
// own template.
func (i *templatedItem) Eval(ctx context.Context) template.HTML {
	var sb strings.Builder

	data, err := i.cb(ctx)
	if err != nil {
		errorTmpl.Execute(&sb, errorData{
			Operation: "Error from item callback",
			Error:     err,
			Item:      data,
		})
		return template.HTML(sb.String())
	}
	if err := i.tmpl.Execute(&sb, data); err != nil {
		errorTmpl.Execute(&sb, errorData{
			Operation: "Error while executing item template",
			Error:     err,
			Item:      data,
		})
	}
	return template.HTML(sb.String())
}

// Handle handles status page requests.
func Handle(w http.ResponseWriter, r *http.Request) {
	data := &statusData{
		Items:        rootItem.items,
		Version:      version.Version(),
		Build:        version.BuildNumber(),
		Hostname:     hostname,
		Username:     username,
		ExePath:      exepath,
		PID:          os.Getpid(),
		Compiler:     runtime.Compiler,
		RuntimeVer:   runtime.Version(),
		GOOS:         runtime.GOOS,
		GOARCH:       runtime.GOARCH,
		NumCPU:       runtime.NumCPU(),
		NumGoroutine: runtime.NumGoroutine(),
		StartTime:    startTime.Format(time.RFC1123),
		StartTimeAgo: time.Since(startTime),
		CurrentTime:  time.Now().Format(time.RFC1123),
		Ctx:          r.Context(),
	}

	// The status template ranges over the items.
	rootItem.mu.RLock()
	defer rootItem.mu.RUnlock()
	if err := statusTmpl.Execute(w, data); err != nil {
		errorTmpl.Execute(w, errorData{
			Operation: "Error while executing main template",
			Error:     err,
			Item:      data,
		})
	}
}

// AddItem adds an item to be displayed on the status page. On each page load,
// the item's callback is called, and the data returned used to fill the
// HTML template in tmpl. The title should be unique (among items under this
// parent.
func AddItem(parent context.Context, title, tmpl string, cb func(context.Context) (any, error)) (context.Context, func()) {
	if cb == nil {
		cb = func(context.Context) (any, error) { return nil, nil }
	}

	item := &templatedItem{
		baseItem: baseItem{
			items: make(map[string]item),
		},
		tmpl: template.New(title).Funcs(funcMap),
		cb:   cb,
	}

	if _, err := item.tmpl.Parse(tmpl); err != nil {
		// Insert an item, but swap the template for the error template, and
		// wrap the callback's return in an errorData.
		item.tmpl = errorTmpl
		item.cb = wrapInItemError("Could not parse item template", err, cb)
	}

	pitem := parentItem(parent)
	pitem.addSubItem(title, item)

	return context.WithValue(parent, itemCtxKey{}, item), func() { pitem.delSubItem(title) }
}

// AddSimpleItem adds a simple status item. Set the value shown by the
// item by calling setStatus.
func AddSimpleItem(parent context.Context, title string) (ctx context.Context, setStatus func(string), done func()) {
	item := &simpleItem{
		baseItem: baseItem{
			items: make(map[string]item),
		},
		stat: "Unknown status",
	}
	pitem := parentItem(parent)
	pitem.addSubItem(title, item)

	return context.WithValue(parent, itemCtxKey{}, item), item.setStatus, func() { pitem.delSubItem(title) }
}

// DelItem removes a status item, specified by the title, from a parent context.
func DelItem(parent context.Context, title string) {
	pitem := item(rootItem)
	if v := parent.Value(itemCtxKey{}); v != nil {
		pitem = v.(item)
	}

	pitem.delSubItem(title)
}

// wrapInItemError takes a callback and returns a new callback wrapping the
// result in an errorData.
func wrapInItemError(op string, err error, cb ItemCallback) ItemCallback {
	return func(ctx context.Context) (any, error) {
		if cb == nil {
			return &errorData{
				Operation: op,
				Error:     err,
			}, nil
		}
		// Surface item callback errors first.
		data, err2 := cb(ctx)
		if err2 != nil {
			return data, err2
		}
		// Surface the item template parse error.
		return &errorData{
			Operation: op,
			Error:     err,
			Item:      data,
		}, nil
	}
}

// printJSON is used as a fallback renderer for item status values.
func printJSON(v any) (string, error) {
	b, err := json.MarshalIndent(v, "", "  ")
	return string(b), err
}

const statusTemplate = `{{- define "render_items" -}}
    {{- range $title, $item := . -}}
    <details open>
        <summary>{{$title}}</summary>
        <div class="itemdata">{{$item.Eval $.Ctx}}</div>
        <div class="subitems">{{template "render_items" $item.Items}}</div>
    </details>
    {{- end -}}
{{- end -}}
<!DOCTYPE html>
<html>
<head>
    <title>Status for defn build agent</title>
    <style>
    body { font-family: sans-serif; background: #fff; }
    h1 { clear: both; width: 100%; text-align: center; font-size: 120%; background: #eef; padding: 4px; }
    summary { width: 100%; font-size: 120%; background: #eef; padding: 0.2em; border: 1px #eef solid; }
    details { display: block; padding: 1em 0; }
    details[open] > summary { background: #fff; border: 1px #000 solid; }
    .error { background: #fee; }
    div { padding: 0.2em; }
    div.warning { background: #ffd; }
    .itemdata { margin: 0 0 0.5em 0.86em; padding: 0.5em 0em 0.5em 1.5em; border-left: 0.1em #ccc dotted; }
    .subitems { margin: 0 0 0.5em 0.86em; padding: 0.5em 0em 0.5em 1.5em; border-left: 0.1em #ccc dotted; border-bottom: 0.1em #ccc dotted; }
    </style>
</head>
<body>
    <h1>Status for defn build agent</h1>
    <div class="summary">
        {{.ExePath}}<br>
        Started at {{.StartTime}} ({{.StartTimeAgo}} ago)<br>
        Current time {{.CurrentTime}}<br>
        Version {{.Version}}, build {{.Build}}<br>
        Running in PID {{.PID}} as {{.Username}} on {{.Hostname}}<br>
        {{.RuntimeVer}} on {{.GOOS}}/{{.GOARCH}} compiled by {{.Compiler}}<br>
        {{.NumGoroutine}} goroutines running/{{.NumCPU}} logical CPUs usable<br>
    </div>
    {{template "render_items" .Items}}
</body>
</html>`
