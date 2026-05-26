@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@build_buf_gen_go_bufbuild_protovalidate_protocolbuffers_go//buf/validate",
	"@org_golang_google_protobuf//reflect/protoreflect",
	"@org_golang_google_protobuf//runtime/protoimpl",
]
