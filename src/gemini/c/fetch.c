#include "fetch.h"

int setup_connect(char *hostname, Connection *conn) {
  struct hostent *host;
  struct sockaddr_in addr;

  conn->sock = socket(AF_INET, SOCK_STREAM, 0);
  host = gethostbyname(hostname);
  if (!host) {
    return FAIL;
  }

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(GEMINI_PORT);
  memcpy(&addr.sin_addr, host->h_addr, host->h_length);

  if (connect(conn->sock, (struct sockaddr *)&addr, sizeof(addr))) {
    return FAIL;
  }

  SSL_library_init();
  conn->ctx = SSL_CTX_new(TLS_client_method());
  SSL_CTX_set_verify(conn->ctx, SSL_VERIFY_NONE, NULL);
  conn->ssl = SSL_new(conn->ctx);

  SSL_set_fd(conn->ssl, conn->sock);
  SSL_set_tlsext_host_name(conn->ssl, hostname);
  return SSL_connect(conn->ssl) == 1 ? OK : FAIL;
}

int get_server_cert_info(Connection *conn, CertificateInfo *info) {
  X509 *cert = SSL_get_peer_certificate(conn->ssl);
  if (!cert) {
    return FAIL;
  }

  const X509_NAME *subject = X509_get_subject_name(cert);
  const int nid = X509_NAME_get_index_by_NID(subject, NID_commonName, -1);
  if (nid < 0) {
    X509_free(cert);
    return FAIL;
  }

  const ASN1_STRING *data =
      X509_NAME_ENTRY_get_data(X509_NAME_get_entry(subject, nid));
  if (!data) {
    X509_free(cert);
    return FAIL;
  }

  uint8_t *hostname;
  int length = ASN1_STRING_to_UTF8(&hostname, data);
  if (length < 0) {
    X509_free(cert);
    return FAIL;
  }

  strncpy(info->hostname, (char *)hostname, length);
  free(hostname);

  uint32_t n;
  if (!X509_digest(cert, EVP_sha256(), (uint8_t *)info->fingerprint, &n)) {
    X509_free(cert);
    return FAIL;
  }

  BIO *bio = BIO_new(BIO_s_mem());
  ASN1_TIME *expiry = X509_get_notAfter(cert);

  if (!ASN1_TIME_print(bio, expiry)) {
    BIO_free(bio);
    X509_free(cert);
    return FAIL;
  }

  BUF_MEM *buf;
  BIO_get_mem_ptr(bio, &buf);

  tm_t tm = {0};
  if (!strptime(buf->data, "%b %d %H:%M:%S %Y %Z", &tm) ||
      !strftime(info->expiry, sizeof(info->expiry), "%Y%m%d%H%M%SZ", &tm)) {
    BIO_free(bio);
    X509_free(cert);
    return FAIL;
  }

  BIO_free(bio);
  X509_free(cert);
  return OK;
}

int write_request(Connection *conn, char *url) {
  char request[MAX_REQUEST] = {0};
  snprintf(request, sizeof(request), "%s\r\n", url);
  if (SSL_write(conn->ssl, request, strlen(request)) <= 0) {
    return FAIL;
  }
  return OK;
}

int read_header(Connection *conn, Response *response) {
  char header[MAX_HEADER_SIZE] = {0};
  int header_pos = 0, n;
  char c;
  while (header_pos < sizeof(header) - 1) {
    n = SSL_read(conn->ssl, &c, 1);
    if (n <= 0) {
      return FAIL;
    }
    header[header_pos++] = c;
    if (c == '\n') {
      break;
    }
  }
  sscanf(header, "%d %[^\r\n]", &response->code, response->meta);
  return OK;
}

int read_body(Connection *conn, Response *response) {
  int body_size = INITIAL_BUFFER_SIZE, n;
  response->body = malloc(body_size);
  response->body_len = 0;
  if (response->body == NULL) {
    return FAIL;
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
        return FAIL;
      }
    }
  }
  return OK;
}

void free_connection(Connection *conn) {
  if (conn->ssl) {
    SSL_shutdown(conn->ssl);
    SSL_free(conn->ssl);
  }
  if (conn->sock != FAIL) {
    close(conn->sock);
  }
  if (conn->ctx) {
    SSL_CTX_free(conn->ctx);
  }
}

void free_reponse(Response *response) {
  if (response->body) {
    free(response->body);
  }
}
