import { FunctionsFetchError, FunctionsHttpError, FunctionsRelayError } from '@supabase/supabase-js';
import { afterEach, describe, expect, it } from 'vitest';
import {
  ApiError,
  ERROR_TEXT,
  GENERIC_CODE,
  errorText,
  fromFunctionsError,
  fromPostgrestError,
} from './errors.ts';

// Later epics add their keys to ERROR_TEXT; these stand in for them.
const added = ['not_class_teacher', 'already_enrolled'];
afterEach(() => {
  for (const key of added) delete ERROR_TEXT[key];
});
function addKey(key: string, text: string) {
  ERROR_TEXT[key] = text;
}

function httpError(status: number, body: string): FunctionsHttpError {
  return new FunctionsHttpError(new Response(body, { status }));
}

describe('fromPostgrestError', () => {
  it('uses the key and its text when the map knows the key', () => {
    addKey('not_class_teacher', 'Only the class teacher can do that.');
    const err = fromPostgrestError({ code: '42501', message: 'not_class_teacher' });
    expect(err).toBeInstanceOf(ApiError);
    expect(err.code).toBe('not_class_teacher');
    expect(err.text).toBe('Only the class teacher can do that.');
    expect(err.sqlstate).toBe('42501');
    expect(err.detail).toBe('not_class_teacher');
  });

  it('keeps an unknown key but shows the SQLSTATE text', () => {
    const err = fromPostgrestError({ code: 'P0002', message: 'no_such_thing' });
    expect(err.code).toBe('no_such_thing');
    expect(err.text).toBe(ERROR_TEXT.not_found);
  });

  it.each([
    ['42501', 'forbidden'],
    ['P0002', 'not_found'],
    ['22023', 'invalid_input'],
    ['23505', 'duplicate'],
  ])('%s with a prose message uses the %s code and text', (sqlstate, code) => {
    const err = fromPostgrestError({ code: sqlstate, message: 'permission denied for table x' });
    expect(err.code).toBe(code);
    expect(err.text).toBe(ERROR_TEXT[code]);
    expect(err.detail).toBe('permission denied for table x');
  });

  it('falls back to the generic text for an unknown SQLSTATE', () => {
    const err = fromPostgrestError({ code: 'XX000', message: 'boom' });
    expect(err.code).toBe('unknown_error');
    expect(err.text).toBe(ERROR_TEXT[GENERIC_CODE]);
    expect(err.text).not.toContain('boom');
  });

  it('falls back to the generic text for an empty code', () => {
    const err = fromPostgrestError({ code: '', message: 'boom' });
    expect(err.code).toBe('unknown_error');
    expect(err.sqlstate).toBeUndefined();
  });

  it('maps a transport failure (empty code, error-name prefix) to network_error', () => {
    const err = fromPostgrestError({ code: '', message: 'TypeError: Failed to fetch' });
    expect(err.code).toBe('network_error');
    expect(err.text).toBe(ERROR_TEXT.network_error);
    expect(err.detail).toBe('TypeError: Failed to fetch');
  });

  it('keeps an empty code with any other message as unknown_error', () => {
    const err = fromPostgrestError({ code: '', message: 'something else' });
    expect(err.code).toBe('unknown_error');
  });

  it('never shows raw server text', () => {
    const err = fromPostgrestError({ code: '42501', message: 'DB password is hunter2' });
    expect(err.text).not.toContain('hunter2');
    expect(err.message).toBe(err.text);
  });

  it('does not treat Object.prototype names as keys', () => {
    const err = fromPostgrestError({ code: 'XX000', message: 'constructor' });
    expect(err.code).toBe('unknown_error');
    expect(err.text).toBe(ERROR_TEXT[GENERIC_CODE]);
  });
});

describe('fromFunctionsError', () => {
  it('reads the code from an AD-17 body and uses its mapped text', async () => {
    addKey('already_enrolled', 'That student is already enrolled.');
    const err = await fromFunctionsError(
      httpError(409, JSON.stringify({ error: { code: 'already_enrolled', message: 'x' } })),
    );
    expect(err.code).toBe('already_enrolled');
    expect(err.text).toBe('That student is already enrolled.');
    expect(err.status).toBe(409);
    expect(err.detail).toBe('x');
  });

  it("uses the status's text for a code the map does not know", async () => {
    const err = await fromFunctionsError(
      httpError(409, JSON.stringify({ error: { code: 'already_enrolled', message: 'x' } })),
    );
    expect(err.code).toBe('already_enrolled');
    expect(err.text).toBe(ERROR_TEXT.conflict);
  });

  it('takes the code from the status when the body is not JSON', async () => {
    const err = await fromFunctionsError(httpError(404, '<html>nope</html>'));
    expect(err.code).toBe('not_found');
    expect(err.text).toBe(ERROR_TEXT.not_found);
    expect(err.status).toBe(404);
  });

  it.each([
    [{ error: 'a string' }],
    [{ error: { message: 'no code' } }],
    [{ error: null }],
    [{ nope: true }],
    [null],
    ['text'],
  ])('takes the code from the status when the body is %j', async (body) => {
    const err = await fromFunctionsError(httpError(422, JSON.stringify(body)));
    expect(err.code).toBe('invalid_input');
    expect(err.text).toBe(ERROR_TEXT.invalid_input);
  });

  it.each([
    [401, 'unauthenticated'],
    [403, 'forbidden'],
    [404, 'not_found'],
    [409, 'conflict'],
    [422, 'invalid_input'],
    [500, 'internal_error'],
  ])('maps status %i to %s', async (status, code) => {
    const err = await fromFunctionsError(httpError(status, ''));
    expect(err.code).toBe(code);
    expect(err.text).toBe(ERROR_TEXT[code]);
  });

  it('falls back to the generic text for an unmapped status without a usable body', async () => {
    const err = await fromFunctionsError(httpError(502, ''));
    expect(err.code).toBe('unknown_error');
    expect(err.text).toBe(ERROR_TEXT[GENERIC_CODE]);
  });

  it('never shows the body message', async () => {
    const err = await fromFunctionsError(
      httpError(500, JSON.stringify({ error: { code: 'internal_error', message: 'db password' } })),
    );
    expect(err.text).not.toContain('db password');
    expect(err.detail).toBe('db password');
  });

  it('maps a fetch error to network_error', async () => {
    const err = await fromFunctionsError(new FunctionsFetchError(new TypeError('Failed to fetch')));
    expect(err.code).toBe('network_error');
    expect(err.text).toBe(ERROR_TEXT.network_error);
  });

  it('maps a relay error to network_error', async () => {
    const err = await fromFunctionsError(new FunctionsRelayError({}));
    expect(err.code).toBe('network_error');
  });

  it('maps anything else to unknown_error', async () => {
    const err = await fromFunctionsError(new Error('weird'));
    expect(err.code).toBe('unknown_error');
    expect(err.detail).toBe('weird');
    expect((await fromFunctionsError('weird')).detail).toBeUndefined();
  });
});

describe('errorText', () => {
  it('returns the mapped text, else the generic text', () => {
    expect(errorText('forbidden')).toBe(ERROR_TEXT.forbidden);
    expect(errorText('no_such_key')).toBe(ERROR_TEXT[GENERIC_CODE]);
    expect(errorText('toString')).toBe(ERROR_TEXT[GENERIC_CODE]);
  });
});
