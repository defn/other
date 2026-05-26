package tui

import (
	"github.com/charmbracelet/lipgloss"
)

// Shared styles for TUI components.
var (
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("205"))

	ErrorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("196"))

	SuccessStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("46"))
)
