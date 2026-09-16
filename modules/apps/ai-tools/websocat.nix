# =========================================================================
# AI TOOLS: websocat — netcat/curl for WebSockets and HTTP streams
# =========================================================================
# Why: LLM APIs stream their output (SSE over HTTP, or raw WebSockets), and
# debugging "why is the stream empty/half-truncated" needs a client that can
# speak streams directly, not just request/response:
#     websocat "wss://host/v1/realtime"          # raw WS session
#     curl -N ... | jq -c 'select(.type)'        # SSE lines (curl -N = no buffer)
# websocat is the missing piece between curl (single response) and a full
# client: one-off probes, header experiments, reconnect tests.
#
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    websocat
  ];
}
