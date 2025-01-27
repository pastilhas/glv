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

#define OK 0
#define FAIL -1
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
  char meta[MAX_HEADER_SIZE];
  char *body;
} Response;

typedef struct {
  char host[256];
  unsigned char fingerprint[32];
  char expiry[32];
} CertificateInfo;

typedef struct tm tm_t;

char *strptime(const char *__restrict s, const char *__restrict fmt, tm_t *tp);

int fetch(const char *url, Response *response);

/**
 * Set up a TLS connection to a Gemini server.
 * Performs DNS lookup, creates socket connection, and initializes SSL.
 *
 * @param hostname The hostname to connect to
 * @param conn The Connection struct to initialize
 * @return 0 on success, -1 on failure
 */
int setup_connect(char *hostname, Connection *conn);

/**
 * Read the response header from a Gemini connection.
 * Reads the response header until a newline character is encountered.
 * Parses the status code and meta information from the header.
 *
 * @param conn The Connection struct containing the SSL connection
 * @param response The Response struct to store the header information
 * @return 0 on success, -1 on failure
 */
int read_header(Connection *conn, Response *response);

/**
 * Read the response body from a Gemini connection.
 * Dynamically allocates memory for the response body and reads
 * data from the connection until EOF or error.
 *
 * @param conn The Connection struct containing the SSL connection
 * @param response The Response struct to store the body data
 * @return 0 on success, -1 on failure
 */
int read_body(Connection *conn, Response *response);

/**
 * Cleanup function for a Gemini connection.
 * Frees all resources associated with a connection including
 * SSL context, connection, and socket.
 *
 * @param conn The Connection struct to cleanup
 */
void free_connection(Connection *conn);

/**
 * Cleanup function for a Gemini response.
 * Frees all memory allocated for response meta and body.
 *
 * @param response The Response struct to cleanup
 */
void free_reponse(Response *response);

/**
 * Get certificate information from an SSL connection.
 * Retrieves the server's certificate fingerprint and expiry date.
 *
 * @param ssl The SSL connection to get certificate info from
 * @param info The CertificateInfo struct to populate
 * @return 0 on success, -1 on failure
 */
int get_server_cert_info(SSL *ssl, CertificateInfo *info);

int write_cert_info(const char *filename, const CertificateInfo *info);

int read_cert_info(const char *filename, const char *host,
                   CertificateInfo *info);

#endif
