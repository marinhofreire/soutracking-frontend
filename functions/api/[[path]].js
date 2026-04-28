const DEFAULT_TRACCAR_PROXY_ORIGIN = "https://app.mackflow.com.br";

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "Access-Control-Allow-Headers":
      request.headers.get("Access-Control-Request-Headers") ||
      "authorization,content-type,accept",
    "Vary": "Origin"
  };
}

export async function onRequest(context) {
  const { request, env, params } = context;

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(request),
    });
  }

  const incomingUrl = new URL(request.url);
  const targetOrigin = String(env?.TRACCAR_PROXY_ORIGIN || DEFAULT_TRACCAR_PROXY_ORIGIN).replace(/\/+$/, "");

  const pathParam = params.path;
  const path = Array.isArray(pathParam) ? pathParam.join("/") : String(pathParam || "");
  const targetUrl = `${targetOrigin}/api/${path}${incomingUrl.search}`;

  const headers = new Headers();
  const authorization = request.headers.get("authorization");
  const contentType = request.headers.get("content-type");
  const accept = request.headers.get("accept");

  if (authorization) headers.set("authorization", authorization);
  if (contentType) headers.set("content-type", contentType);
  if (accept) headers.set("accept", accept);

  const upstreamResponse = await fetch(targetUrl, {
    method: request.method,
    headers,
    body: ["GET", "HEAD"].includes(request.method) ? undefined : request.body,
  });

  const responseHeaders = new Headers(upstreamResponse.headers);
  for (const [key, value] of Object.entries(corsHeaders(request))) {
    responseHeaders.set(key, value);
  }
  responseHeaders.delete("content-length");
  responseHeaders.set("x-soutracking-target", targetUrl);

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    headers: responseHeaders,
  });
}
