#ifndef GEMINI_FETCH_H
#define GEMINI_FETCH_H

#include <malloc.h>
#include <netdb.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <resolv.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define GEMINI_PORT 1965
#define MAX_BODY_SIZE 65536
#define MAX_HOSTNAME 256
#define MAX_REQUEST 1024
#define MAX_HEADER_SIZE 1024

typedef struct {
  SSL_CTX *ctx;
  SSL *ssl;
  int sock;
} Connection;

typedef struct {
  int status_code;
  int meta_length;
  int body_length;
  char *meta;
  char *body;
} GeminiResponse;

int fetch(const char *url, GeminiResponse *response);

int setup_connect(char *hostname, Connection *conn);

int read_header(Connection *conn, GeminiResponse *response);

void cleanup(Connection *conn);

void free_reponse(GeminiResponse *response);

#endif
