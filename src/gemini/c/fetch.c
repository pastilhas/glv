#include "fetch.h"
#include <openssl/asn1.h>
#include <openssl/crypto.h>
#include <string.h>

int fetch(const char *url, Response *response) {
  Connection conn;

  char hostname[MAX_HOSTNAME], request[MAX_REQUEST];

  if (sscanf(url, "gemini://%255[^/]", hostname) != 1) {
    return -1;
  }

  if (setup_connect(hostname, &conn) < 0) {
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

  if (response->code / 10 == 2 && read_body(&conn, response)) {
    cleanup(&conn);
    return -1;
  }

  cleanup(&conn);
  return response->code;
}

int setup_connect(char *hostname, Connection *conn) {
  struct hostent *host;
  struct sockaddr_in addr;

  SSL_library_init();
  conn->ctx = SSL_CTX_new(TLS_client_method());
  SSL_CTX_set_verify(conn->ctx, SSL_VERIFY_NONE, NULL);
  conn->ssl = SSL_new(conn->ctx);

  conn->sock = socket(AF_INET, SOCK_STREAM, 0);
  host = gethostbyname(hostname);
  if (!host) {
    return -1;
  }

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(GEMINI_PORT);
  memcpy(&addr.sin_addr, host->h_addr, host->h_length);

  if (connect(conn->sock, (struct sockaddr *)&addr, sizeof(addr))) {
    return -1;
  }

  SSL_set_fd(conn->ssl, conn->sock);
  SSL_set_tlsext_host_name(conn->ssl, hostname);

  if (SSL_connect(conn->ssl) != 1) {
    return -1;
  }

  X509 *cert = SSL_get_peer_certificate(conn->ssl);
  if (cert == NULL) {
    return -1;
  }

  unsigned char fingerprint[32];
  unsigned int n;
  if (!X509_digest(cert, EVP_sha256(), fingerprint, &n)) {
    return -1;
  }

  ASN1_TIME *expiryDate = X509_get_notAfter(cert);

  X509_free(cert);

  return 0;
}

int read_header(Connection *conn, Response *response) {
  char header[MAX_HEADER_SIZE] = {0};
  int header_pos = 0;
  char c;
  int n;
  while (header_pos < sizeof(header) - 1) {
    n = SSL_read(conn->ssl, &c, 1);
    if (n <= 0) {
      return -1;
    }
    header[header_pos++] = c;
    if (c == '\n') {
      break;
    }
  }
  response->meta = malloc(MAX_HEADER_SIZE);
  if (response->meta == NULL) {
    return -1;
  }
  sscanf(header, "%d %[^\r\n]", &response->code, response->meta);
  response->meta_len = strlen(response->meta);
  return 0;
}

int read_body(Connection *conn, Response *response) {
  int body_size = INITIAL_BUFFER_SIZE;
  int n;
  response->body = malloc(body_size);
  response->body_len = 0;
  if (response->body == NULL) {
    return -1;
  }
  while (1) {
    n = SSL_read(conn->ssl, response->body + response->body_len,
                 body_size - response->body_len - 1);
    if (n <= 0) {
      break;
    }
    response->body_len += n;
    if (response->body_len >= body_size - 1) {
      response->body = realloc(response->body, (body_size *= 2));
      if (response->body == NULL) {
        return -1;
      }
    }
  }
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

void free_reponse(Response *response) {
  if (response) {
    free(response->meta);
    free(response->body);
  }
}
