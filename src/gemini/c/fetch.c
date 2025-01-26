#include "fetch.h"

int setup_connect(char *hostname, int conn) {
  struct hostent *host;
  struct sockaddr_in server_addr;

  host = gethostbyname(hostname);
  if (!host)
    return -1;

  memset(&server_addr, 0, sizeof(server_addr));
  server_addr.sin_family = AF_INET;
  server_addr.sin_port = htons(GEMINI_PORT);
  memcpy(&server_addr.sin_addr, host->h_addr, host->h_length);

  return connect(conn, (struct sockaddr *)&server_addr, sizeof(server_addr));
}

int fetch(const char *url, GeminiResponse *response) {
  SSL_CTX *ctx;
  SSL *ssl;
  int conn = -1;
  char hostname[MAX_HOSTNAME], request[MAX_REQUEST];

  if (sscanf(url, "gemini://%255[^/]", hostname) != 1) {
    return -1;
  }

  SSL_library_init();
  ctx = SSL_CTX_new(TLS_client_method());
  SSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, NULL);

  conn = socket(AF_INET, SOCK_STREAM, 0);
  if (setup_connect(hostname, conn) < 0) {
    cleanup(ctx, ssl, conn);
    return -1;
  }

  ssl = SSL_new(ctx);
  SSL_set_fd(ssl, conn);
  SSL_set_tlsext_host_name(ssl, hostname);

  if (SSL_connect(ssl) != 1) {
    cleanup(ctx, ssl, conn);
    return -1;
  }

  snprintf(request, sizeof(request), "%s\r\n", url);

  if (SSL_write(ssl, request, strlen(request)) <= 0) {
    cleanup(ctx, ssl, conn);
    return -1;
  }

  char header[1024] = {0};
  int header_pos = 0;
  char c;
  while (header_pos < sizeof(header) - 1) {
    int n = SSL_read(ssl, &c, 1);
    if (n <= 0) {
      cleanup(ctx, ssl, conn);
      return -1;
    }
    header[header_pos++] = c;
    if (c == '\n') {
      break;
    }
  }
  header[header_pos] = '\0';

  response->meta = malloc(MAX_HEADER_SIZE);
  sscanf(header, "%d %[^\r\n]", &response->status_code, response->meta);
  response->meta_length = strlen(response->meta);

  if (response->status_code / 10 != 2) {
    cleanup(ctx, ssl, conn);
    return response->status_code;
  }

  response->body = malloc(MAX_BODY_SIZE);
  while (response->body_length < MAX_BODY_SIZE - 1) {
    int n = SSL_read(ssl, response->body + response->body_length,
                     MAX_BODY_SIZE - response->body_length - 1);
    if (n <= 0) {
      break;
    }
    response->body_length += n;
  }
  response->body[response->body_length] = '\0';
  return response->status_code;
}

void cleanup(SSL_CTX *ctx, SSL *ssl, int conn) {
  if (ssl) {
    SSL_shutdown(ssl);
    SSL_free(ssl);
  }
  if (conn != -1) {
    close(conn);
  }
  if (ctx) {
    SSL_CTX_free(ctx);
  }
}

void free_reponse(GeminiResponse *response) {
  if (response) {
    free(response->meta);
    free(response->body);
  }
}
