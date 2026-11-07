// How every edge function answers an error (AD-17): the real HTTP status and
// `{ "error": { "code": "<key>", "message": "<text>" } }`. The app shows its
// own text for the code (app/src/api/errors.ts), never this message. Plain
// Deno and Web APIs only: no third-party imports.
import { corsHeaders } from './cors.ts';

export const INTERNAL_CODE = 'internal_error';
export const INTERNAL_MESSAGE = 'Internal error';

// A handler throws this for a refusal it names.
export class HttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
  }
}

export function errorResponse(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// The response for anything a handler threw. Only an HttpError's own text
// reaches the body; anything else is logged and answered as a bare 500.
export function toErrorResponse(err: unknown): Response {
  if (err instanceof HttpError) {
    return errorResponse(err.status, err.code, err.message);
  }
  console.error(err);
  return errorResponse(500, INTERNAL_CODE, INTERNAL_MESSAGE);
}

// AD-17's SQLSTATEs: status, the code used when the message is not a key, and
// the body message.
const SQLSTATES: Record<string, { status: number; code: string; message: string }> = {
  '42501': { status: 403, code: 'forbidden', message: 'Forbidden' },
  P0002: { status: 404, code: 'not_found', message: 'Not found' },
  '22023': { status: 422, code: 'invalid_input', message: 'Invalid input' },
  '23505': { status: 409, code: 'duplicate', message: 'Duplicate' },
};

// A SQL message key is stable snake_case. Anything else is prose.
const KEY = /^[a-z][a-z0-9_]*$/;

// The HttpError for an error an RPC returned (`{ code: <SQLSTATE>, message:
// <key> }`). An unknown SQLSTATE is a 500: the original is logged, not sent.
export function fromRpcError(err: { code?: unknown; message?: unknown }): HttpError {
  const sqlstate = typeof err.code === 'string' ? err.code : '';
  if (!Object.hasOwn(SQLSTATES, sqlstate)) {
    console.error(err);
    return new HttpError(500, INTERNAL_CODE, INTERNAL_MESSAGE);
  }
  const known = SQLSTATES[sqlstate];
  const key = typeof err.message === 'string' && KEY.test(err.message) ? err.message : known.code;
  return new HttpError(known.status, key, known.message);
}
