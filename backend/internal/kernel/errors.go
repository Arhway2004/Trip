// Package kernel is the shared kernel: small, dependency-free building blocks
// (error kinds, calendar dates, clock, IDs) used by every bounded context.
package kernel

import (
	"errors"
	"fmt"
)

// Kind classifies an error so that adapters (HTTP, jobs) can map it without
// knowing the domain that produced it.
type Kind int

const (
	KindInternal Kind = iota
	KindValidation
	KindNotFound
	KindForbidden
	KindConflict
	KindPreconditionFailed
	KindUnauthenticated
	KindUnavailable // a dependency (e.g. an external API) is not available
)

// FieldError describes one invalid input field.
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// Error is the error type returned by domain and application code.
type Error struct {
	Kind    Kind
	Code    string // stable, machine-readable, e.g. "trip.title_required"
	Message string // human-readable
	Fields  []FieldError
	Err     error
}

func (e *Error) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Err)
	}
	return e.Message
}

func (e *Error) Unwrap() error { return e.Err }

func newErr(k Kind, code, msg string) *Error { return &Error{Kind: k, Code: code, Message: msg} }

func Validation(code, msg string, fields ...FieldError) *Error {
	return &Error{Kind: KindValidation, Code: code, Message: msg, Fields: fields}
}
func NotFound(code, msg string) *Error        { return newErr(KindNotFound, code, msg) }
func Forbidden(code, msg string) *Error       { return newErr(KindForbidden, code, msg) }
func Conflict(code, msg string) *Error        { return newErr(KindConflict, code, msg) }
func Unauthenticated(code, msg string) *Error { return newErr(KindUnauthenticated, code, msg) }
func Unavailable(code, msg string) *Error     { return newErr(KindUnavailable, code, msg) }
func PreconditionFailed(code, msg string) *Error {
	return newErr(KindPreconditionFailed, code, msg)
}

// KindOf returns the Kind of err, or KindInternal for unknown errors.
func KindOf(err error) Kind {
	var e *Error
	if errors.As(err, &e) {
		return e.Kind
	}
	return KindInternal
}
