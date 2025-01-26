#ifndef GEMINI_FETCH_H
#define GEMINI_FETCH_H

#include <malloc.h>
#include <netdb.h>
#include <openssl/asn1.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>
#include <pwd.h>
#include <resolv.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define GEMINI_PORT 1965
#define MAX_HOSTNAME 256
#define MAX_REQUEST 1024
#define MAX_HEADER_SIZE 1024
#define INITIAL_BUFFER_SIZE 1024
#define KNOWN_HOSTS_FILE ".gemini_hosts"

typedef struct {
  SSL_CTX *ctx;
  SSL *ssl;
  int sock;
} Connection;

typedef struct {
  int code;
  int meta_len;
  int body_len;
  char *meta;
  char *body;
} Response;

typedef struct {
  char host[256];
  unsigned char fingerprint[32];
  char expiry[32];
} CertificateInfo;

int fetch(const char *url, Response *response);

int setup_connect(char *hostname, Connection *conn);

int read_header(Connection *conn, Response *response);

int read_body(Connection *conn, Response *response);

void cleanup(Connection *conn);

void free_reponse(Response *response);

int get_cert_info(SSL *ssl, CertificateInfo *info);

int write_cert_info(const char *filename, const CertificateInfo *info);

int read_cert_info(const char *filename, const char *host,
                   CertificateInfo *info);

#endif
