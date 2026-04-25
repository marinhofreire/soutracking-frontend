const DEFAULT_TRACCAR_PROXY_ORIGIN = "http://204.168.191.10";

function resolveTargetOrigin(env) {
  return String(env?.TRACCAR_PROXY_ORIGIN || DEFAULT_TRACCAR_PROXY_ORIGIN)
    .trim()
    .replace(/\/+$/, "");
}

function buildPreflightHeaders(request) {
  const origin = request.headers.get("Origin") || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS",
    "Access-Control-Allow-Headers":
      request.headers.get("Access-Control-Request-Headers") ||
      "authorization,content-type,accept",
    Vary: "Origin",
  };
}

export async function onRequest(context) {
  const { request, env } = context;

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: buildPreflightHeaders(request),
    });
  }

  const incomingUrl = new URL(request.url);
  const targetOrigin = resolveTargetOrigin(env);
  const upstreamUrl = new URL(
    `${targetOrigin}${incomingUrl.pathname}${incomingUrl.search}`,
  );

  const upstreamHeaders = new Headers(request.headers);
  upstreamHeaders.delete("host");

  const upstreamResponse = await fetch(upstreamUrl, {
    method: request.method,
    headers: upstreamHeaders,
    body:
      request.method === "GET" || request.method === "HEAD"
        ? undefined
        : request.body,
    redirect: "manual",
  });

  const responseHeaders = new Headers(upstreamResponse.headers);
  const corsHeaders = buildPreflightHeaders(request);
  for (const [key, value] of Object.entries(corsHeaders)) {
    responseHeaders.set(key, value);
  }
  responseHeaders.set("X-SouTracking-Proxy-Target", targetOrigin);
  responseHeaders.delete("Content-Length");

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });
}
