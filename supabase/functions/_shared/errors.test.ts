// Run from the repo root: deno test --no-lock --permit-no-files supabase/functions
import { corsHeaders } from './cors.ts';
import { errorResponse, fromRpcError, HttpError, toErrorResponse } from './errors.ts';

// Plain asserts: no import, so the tests need no package resolution.
function ok(value: unknown, message = 'expected a truthy value'): asserts value {
  if (!value) throw new Error(message);
}
function eq<T>(actual: T, expected: T): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

// Silences and records console.error for the duration of fn.
async function withLoggedErrors(fn: () => void | Promise<void>): Promise<unknown[][]> {
  const original = console.error;
  const calls: unknown[][] = [];
  console.error = (...args: unknown[]) => {
    calls.push(args);
  };
  try {
    await fn();
  } finally {
    console.error = original;
  }
  return calls;
}

Deno.test('errorResponse: status, JSON body, JSON content type, CORS', async () => {
  const res = errorResponse(403, 'not_class_teacher', 'Forbidden');
  eq(res.status, 403);
  eq(res.headers.get('Content-Type'), 'application/json');
  for (const [name, value] of Object.entries(corsHeaders)) {
    eq(res.headers.get(name), value);
  }
  eq(await res.json(), {
    error: { code: 'not_class_teacher', message: 'Forbidden' },
  });
});

Deno.test('toErrorResponse: an HttpError answers with its own status, code and message', async () => {
  const res = toErrorResponse(new HttpError(403, 'not_class_teacher', 'Not the class teacher'));
  eq(res.status, 403);
  eq(res.headers.get('Content-Type'), 'application/json');
  eq(await res.json(), {
    error: { code: 'not_class_teacher', message: 'Not the class teacher' },
  });
});

Deno.test('toErrorResponse: an unknown throw is a bare 500, logged, text not sent', async () => {
  let res: Response | undefined;
  const logged = await withLoggedErrors(() => {
    res = toErrorResponse(new Error('db password'));
  });
  ok(res);
  eq(res.status, 500);
  const body = await res.text();
  eq(JSON.parse(body), {
    error: { code: 'internal_error', message: 'Internal error' },
  });
  ok(!body.includes('db password'));
  eq(logged.length, 1);
  eq((logged[0][0] as Error).message, 'db password');
});

Deno.test('toErrorResponse: a non-Error throw is also a bare 500', async () => {
  let res: Response | undefined;
  await withLoggedErrors(() => {
    res = toErrorResponse('secret string');
  });
  ok(res);
  eq(res.status, 500);
  ok(!(await res.text()).includes('secret string'));
});

Deno.test('fromRpcError: each AD-17 SQLSTATE maps to its status and keeps the key', () => {
  const cases: [string, number][] = [
    ['42501', 403],
    ['P0002', 404],
    ['22023', 422],
    ['23505', 409],
  ];
  for (const [code, status] of cases) {
    const err = fromRpcError({ code, message: 'some_key' });
    ok(err instanceof HttpError);
    eq(err.status, status);
    eq(err.code, 'some_key');
  }
});

Deno.test('fromRpcError: a duplicate answers 409 with the SQL key', async () => {
  const res = toErrorResponse(fromRpcError({ code: '23505', message: 'duplicate_email' }));
  eq(res.status, 409);
  eq((await res.json()).error.code, 'duplicate_email');
});

Deno.test('fromRpcError: a message that is not a key is not sent; the SQLSTATE code is used', async () => {
  const res = toErrorResponse(
    fromRpcError({ code: '42501', message: 'permission denied for table profiles' }),
  );
  eq(res.status, 403);
  const body = await res.text();
  eq(JSON.parse(body).error.code, 'forbidden');
  ok(!body.includes('permission denied'));
});

Deno.test('fromRpcError: an unknown SQLSTATE is a 500 internal_error, logged', async () => {
  let err: HttpError | undefined;
  const logged = await withLoggedErrors(() => {
    err = fromRpcError({ code: 'XX000', message: 'boom' });
  });
  ok(err);
  eq(err.status, 500);
  eq(err.code, 'internal_error');
  eq(err.message, 'Internal error');
  eq(logged.length, 1);
});

Deno.test('fromRpcError: a missing code is a 500 internal_error', async () => {
  let err: HttpError | undefined;
  await withLoggedErrors(() => {
    err = fromRpcError({ message: 'x' });
  });
  eq(err?.status, 500);
  eq(err?.code, 'internal_error');
});
