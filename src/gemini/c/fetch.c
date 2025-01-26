#include "fetch.h"

int fetch(const char *url, GeminiResponse *response) {
  Connection conn;

  char hostname[MAX_HOSTNAME], request[MAX_REQUEST];

  if (sscanf(url, "gemini://%255[^/]", hostname) != 1) {
    return -1;
  }

  SSL_library_init();
  conn.ctx = SSL_CTX_new(TLS_client_method());
  SSL_CTX_set_verify(conn.ctx, SSL_VERIFY_NONE, NULL);
  conn.ssl = SSL_new(conn.ctx);

  if (setup_connect(hostname, &conn) < 0) {
    cleanup(&conn);
    return -1;
  }

  SSL_set_fd(conn.ssl, conn.sock);
  SSL_set_tlsext_host_name(conn.ssl, hostname);

  if (SSL_connect(conn.ssl) != 1) {
    cleanup(&conn);
    return -1;
  }

  snprintf(request, sizeof(request), "%s\r\n", url);

  if (SSL_write(conn.ssl, request, strlen(request)) <= 0) {
    cleanup(&conn);
    return -1;
  }

  if (read_header(&conn, response)) {
    cleanup(&conn);
    return -1;
  }

  if (response->status_code / 10 != 2) {
    cleanup(&conn);
    return response->status_code;
  }

  response->body = malloc(MAX_BODY_SIZE);
  while (response->body_length < MAX_BODY_SIZE - 1) {
    int n = SSL_read(conn.ssl, response->body + response->body_length,
                     MAX_BODY_SIZE - response->body_length - 1);
    if (n <= 0) {
      break;
    }
    response->body_length += n;
  }
  response->body[response->body_length] = '\0';
  return response->status_code;
}

int setup_connect(char *hostname, Connection *conn) {
  struct hostent *host;
  struct sockaddr_in addr;

  conn->sock = socket(AF_INET, SOCK_STREAM, 0);
  host = gethostbyname(hostname);
  if (!host) {
    return -1;
  }

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(GEMINI_PORT);
  memcpy(&addr.sin_addr, host->h_addr, host->h_length);

  return connect(conn->sock, (struct sockaddr *)&addr, sizeof(addr));
}

int read_header(Connection *conn, GeminiResponse *response) {
  char header[1024] = {0};
  int header_pos = 0;
  char c;
  while (header_pos < sizeof(header) - 1) {
    int n = SSL_read(conn->ssl, &c, 1);
    if (n <= 0) {
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
  return 0;
}

void cleanup(Connection *conn) {
  if (conn->ssl) {
    SSL_shutdown(conn->ssl);
    SSL_free(conn->ssl);
  }
  if (conn->sock != -1) {
    close(conn->sock);
  }
  if (conn->ctx) {
    SSL_CTX_free(conn->ctx);
  }
}

void free_reponse(GeminiResponse *response) {
  if (response) {
    free(response->meta);
    free(response->body);
  }
}
