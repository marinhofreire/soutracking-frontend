const DEFAULT_BRIDGE_ORIGIN = "https://bridge.soutracking.com.br";

export async function onRequest(context) {
  const { request, env, params } = context;

  const incomingUrl = new URL(request.url);
  const targetOrigin = String(env?.BRIDGE_ORIGIN || DEFAULT_BRIDGE_ORIGIN).replace(/\/+$/, "");

  const pathParam = params.path;
  const path = Array.isArray(pathParam) ? pathParam.join("/") : String(pathParam || "");
  const targetUrl = `${targetOrigin}/share/${path}${incomingUrl.search}`;

  const upstreamResponse = await fetch(targetUrl, {
    method: request.method,
    headers: { accept: request.headers.get("accept") || "text/html" },
  });

  const responseHeaders = new Headers(upstreamResponse.headers);
  responseHeaders.delete("content-length");

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    headers: responseHeaders,
  });
}
