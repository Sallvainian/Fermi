import {
  FunctionsFetchError,
  FunctionsHttpError,
  FunctionsRelayError,
  type PostgrestError,
} from '@supabase/supabase-js';

// Every error a screen sees is an ApiError, whether it came from a SQL call
// (PostgREST), an edge function or the network (AD-17). A screen shows
// `error.text` and branches on `error.code`.
//
// Error text comes only from ERROR_TEXT. A server's own message is kept in
// `detail` for logs and never shown.
export class ApiError extends Error {
  readonly code: string;
  readonly text: string;
  readonly status?: number;
  readonly sqlstate?: string;
  readonly detail?: string;

  constructor(init: {
    code: string;
    text: string;
    status?: number;
    sqlstate?: string;
    detail?: string;
  }) {
    super(init.text);
    this.name = 'ApiError';
    this.code = init.code;
    this.text = init.text;
    this.status = init.status;
    this.sqlstate = init.sqlstate;
    this.detail = init.detail;
  }
}

export const GENERIC_CODE = 'unknown_error';

// The one key -> text map. A key is a SQL message key or an edge function
// `error.code`. Later epics add their keys here. The codes below it are the
// fallbacks SQLSTATE_CODE and STATUS_CODE point at.
export const ERROR_TEXT: Record<string, string> = {
  forbidden: 'You do not have permission to do that.',
  not_found: 'That could not be found.',
  invalid_input: 'Something in that request is not valid.',
  duplicate: 'That already exists.',
  unauthenticated: 'Please sign in and try again.',
  conflict: 'That conflicts with something that already exists. Refresh and try again.',
  internal_error: 'Something went wrong on our side. Try again.',
  network_error: 'Could not reach the server. Check your connection and try again.',
  [GENERIC_CODE]: 'Something went wrong. Try again.',
};

// AD-17's SQLSTATEs.
const SQLSTATE_CODE: Record<string, string> = {
  '42501': 'forbidden',
  P0002: 'not_found',
  '22023': 'invalid_input',
  '23505': 'duplicate',
};

// AD-17's edge function statuses.
const STATUS_CODE: Record<number, string> = {
  401: 'unauthenticated',
  403: 'forbidden',
  404: 'not_found',
  409: 'conflict',
  422: 'invalid_input',
  500: 'internal_error',
};

// A message key is stable snake_case. Anything else is prose, which is never
// used as a code.
const KEY = /^[a-z][a-z0-9_]*$/;

const TRANSPORT_FAILURE = /^(TypeError|AbortError|TimeoutError|FetchError):/;

function has(map: object, key: string | number): boolean {
  return Object.hasOwn(map, key);
}

export function errorText(code: string): string {
  return has(ERROR_TEXT, code) ? ERROR_TEXT[code] : ERROR_TEXT[GENERIC_CODE];
}

// The key if the map knows it, else the fallback code (the SQLSTATE's or the
// status's), else a key the map does not know but that is well formed. The
// text is the key's, else the fallback's, else generic.
function resolve(key: string | undefined, fallback: string | undefined) {
  const wellFormed = key !== undefined && KEY.test(key) ? key : undefined;
  if (wellFormed !== undefined && has(ERROR_TEXT, wellFormed)) {
    return { code: wellFormed, text: ERROR_TEXT[wellFormed] };
  }
  if (fallback === undefined) {
    return { code: GENERIC_CODE, text: ERROR_TEXT[GENERIC_CODE] };
  }
  return { code: wellFormed ?? fallback, text: ERROR_TEXT[fallback] };
}

// A PostgREST error: `code` is the SQLSTATE, `message` the key the SQL
// function raised with.
export function fromPostgrestError(
  err: Pick<PostgrestError, 'code' | 'message'>,
): ApiError {
  const sqlstate = typeof err.code === 'string' ? err.code : '';
  const fallback = has(SQLSTATE_CODE, sqlstate) ? SQLSTATE_CODE[sqlstate] : undefined;
  const key = typeof err.message === 'string' ? err.message : undefined;
  // postgrest-js reports a transport failure (offline, abort, timeout) as an
  // empty code and '<ErrorName>: <message>'.
  if (sqlstate === '' && key !== undefined && TRANSPORT_FAILURE.test(key)) {
    return new ApiError({ code: 'network_error', text: ERROR_TEXT.network_error, detail: key });
  }
  // An unknown SQLSTATE says nothing about what went wrong, so a key it carries
  // is not trusted either, unless the map already knows it.
  const { code, text } = resolve(key, fallback);
  return new ApiError({
    code,
    text,
    sqlstate: sqlstate || undefined,
    detail: key,
  });
}

function bodyError(body: unknown): { code: string; message?: string } | undefined {
  if (typeof body !== 'object' || body === null) return undefined;
  const error = (body as { error?: unknown }).error;
  if (typeof error !== 'object' || error === null) return undefined;
  const { code, message } = error as { code?: unknown; message?: unknown };
  if (typeof code !== 'string') return undefined;
  return { code, message: typeof message === 'string' ? message : undefined };
}

// An error from `supabase.functions.invoke`. Reads the response body, so it is
// async.
export async function fromFunctionsError(err: unknown): Promise<ApiError> {
  if (err instanceof FunctionsFetchError || err instanceof FunctionsRelayError) {
    return new ApiError({
      code: 'network_error',
      text: ERROR_TEXT.network_error,
      detail: err.message,
    });
  }

  if (err instanceof FunctionsHttpError) {
    const response = err.context as Partial<Response> | undefined;
    const status = typeof response?.status === 'number' ? response.status : undefined;
    const fallback =
      status !== undefined && has(STATUS_CODE, status) ? STATUS_CODE[status] : undefined;

    let parsed: { code: string; message?: string } | undefined;
    if (typeof response?.json === 'function') {
      try {
        parsed = bodyError(await response.json());
      } catch {
        parsed = undefined;
      }
    }

    // A body that is not the AD-17 shape says nothing the status does not.
    const { code, text } = resolve(parsed?.code, fallback);
    return new ApiError({ code, text, status, detail: parsed?.message });
  }

  return new ApiError({
    code: GENERIC_CODE,
    text: ERROR_TEXT[GENERIC_CODE],
    detail: err instanceof Error ? err.message : undefined,
  });
}
