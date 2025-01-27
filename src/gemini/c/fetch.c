#include "fetch.h"
#include <string.h>
#include <time.h>

int fetch(const char *url, Response *response) {
  Connection conn;

  char hostname[MAX_HOSTNAME], request[MAX_REQUEST];

  if (sscanf(url, "gemini://%255[^/]", hostname) != 1) {
    return FAIL;
  }

  if (setup_connect(hostname, &conn) < 0) {
    free_connection(&conn);
    return FAIL;
  }

  CertificateInfo new, old;
  strncpy(new.host, hostname, sizeof(new.host) - 1);
  new.host[sizeof(new.host) - 1] = '\0';
  if (get_server_cert_info(conn.ssl, &new)) {
    free_connection(&conn);
    return FAIL;
  }

  const char *homedir;
  if ((homedir = getenv("HOME")) == NULL) {
    homedir = getpwuid(getuid())->pw_dir;
  }

  int len1 = strlen(homedir);
  int len2 = strlen(KNOWN_HOSTS_FILE);
  int len = len1 + len2 + (homedir[len1 - 1] != '/' ? 1 : 0) + 1;

  char *path = malloc(len);
  snprintf(path, len, "%s%s%s", homedir, homedir[len1 - 1] != '/' ? "/" : "",
           KNOWN_HOSTS_FILE);

  if (read_cert_info(path, hostname, &old) == 0) {
    int pday, psec;
    ASN1_TIME expiry;
    ASN1_TIME_set_string(&expiry, new.expiry);
    ASN1_TIME_diff(&pday, &psec, NULL, &expiry);

    if (pday < 0 && psec < 0) {
      write_cert_info(path, &new);
    } else if (memcmp(new.fingerprint, old.fingerprint,
                      sizeof(old.fingerprint))) {
      free_connection(&conn);
      return FAIL;
    }
  } else {
    write_cert_info(path, &new);
  }

  free(path);

  snprintf(request, sizeof(request), "%s\r\n", url);

  if (SSL_write(conn.ssl, request, strlen(request)) <= 0) {
    free_connection(&conn);
    return FAIL;
  }

  if (read_header(&conn, response) == FAIL) {
    free_connection(&conn);
    return FAIL;
  }

  if (response->code / 10 == 2 && read_body(&conn, response)) {
    free_connection(&conn);
    return FAIL;
  }

  free_connection(&conn);
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
    return FAIL;
  }

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(GEMINI_PORT);
  memcpy(&addr.sin_addr, host->h_addr, host->h_length);

  if (connect(conn->sock, (struct sockaddr *)&addr, sizeof(addr))) {
    return FAIL;
  }

  SSL_set_fd(conn->ssl, conn->sock);
  SSL_set_tlsext_host_name(conn->ssl, hostname);

  if (SSL_connect(conn->ssl) != 1) {
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

  memset(response->meta, 0, sizeof(response->meta));
  sscanf(header, "%d %[^\r\n]", &response->code, response->meta);
  response->meta_len = strlen(response->meta);
  return response->code;
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
  if (response) {
    free(response->body);
  }
}

int get_server_cert_info(SSL *ssl, CertificateInfo *info) {
  X509 *cert = SSL_get_peer_certificate(ssl);
  if (cert == NULL) {
    return FAIL;
  }

  unsigned int n;
  if (!X509_digest(cert, EVP_sha256(), info->fingerprint, &n)) {
    X509_free(cert);
    return FAIL;
  }
  ASN1_TIME *expiry = X509_get_notAfter(cert);
  BIO *bio = BIO_new(BIO_s_mem());
  if (ASN1_TIME_print(bio, expiry)) {
    BUF_MEM *buf;
    BIO_get_mem_ptr(bio, &buf);
    tm_t tm;
    memset(&tm, 0, sizeof(tm));
    if (strptime(buf->data, "%b %d %H:%M:%S %Y %Z", &tm)) {
      strftime(info->expiry, sizeof(info->expiry), "%Y%m%d%H%M%SZ", &tm);
    } else {
      strcpy(info->expiry, "Unknown");
    }
  } else {
    strcpy(info->expiry, "Unknown");
  }
  BIO_free(bio);
  X509_free(cert);
  return OK;
}

int write_cert_info(const char *filename, const CertificateInfo *info) {
  FILE *fp = fopen(filename, "a");
  if (fp == NULL) {
    return FAIL;
  }
  fprintf(fp, "%s ", info->host);
  fprintf(fp,
          "%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%"
          "02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%"
          "02X:%02X:%02X:%02X:%02X:%02X",
          info->fingerprint[0], info->fingerprint[1], info->fingerprint[2],
          info->fingerprint[3], info->fingerprint[4], info->fingerprint[5],
          info->fingerprint[6], info->fingerprint[7], info->fingerprint[8],
          info->fingerprint[9], info->fingerprint[10], info->fingerprint[11],
          info->fingerprint[12], info->fingerprint[13], info->fingerprint[14],
          info->fingerprint[15], info->fingerprint[16], info->fingerprint[17],
          info->fingerprint[18], info->fingerprint[19], info->fingerprint[20],
          info->fingerprint[21], info->fingerprint[22], info->fingerprint[23],
          info->fingerprint[24], info->fingerprint[25], info->fingerprint[26],
          info->fingerprint[27], info->fingerprint[28], info->fingerprint[29],
          info->fingerprint[30], info->fingerprint[31]);
  fprintf(fp, " %s\n", info->expiry);
  fclose(fp);
  return OK;
}

int read_cert_info(const char *filename, const char *host,
                   CertificateInfo *info) {
  FILE *fp = fopen(filename, "r");
  if (fp == NULL) {
    FILE *fp = fopen(filename, "w");
    fclose(fp);
    return FAIL;
  }

  char line[512];
  while (fgets(line, sizeof(line), fp)) {
    char *token = strtok(line, " ");
    if (token && strcmp(token, host) == 0) {
      token = strtok(NULL, " ");
      if (token) {
        char *fingerprint = token;
        for (int i = 0; i < 32; i++) {
          char hex[3];
          hex[0] = fingerprint[i * 3];
          hex[1] = fingerprint[i * 3 + 1];
          hex[2] = '\0';
          info->fingerprint[i] = (unsigned char)strtol(hex, NULL, 16);
        }
      }

      token = strtok(NULL, " ");
      if (token) {
        strncpy(info->expiry, token, sizeof(info->expiry) - 1);
        info->expiry[sizeof(info->expiry) - 1] = '\0';
      }
      strncpy(info->host, host, sizeof(info->host) - 1);
      info->host[sizeof(info->host) - 1] = '\0';

      fclose(fp);
      return OK;
    }
  }

  fclose(fp);
  return FAIL;
}
