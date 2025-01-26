# GLV - Gemini Library in V

GLV is a [Gemini Protocol](<https://en.wikipedia.org/wiki/Gemini_(protocol)>) library written in [V](https://vlang.io/).
It provides a simple interface to interact with Gemini servers and helps developers build Gemini clients.

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
   - [Prerequisites](#prerequisites)
   - [Building](#building)
3. [Usage](#usage)
   - [Response Structure](#response-structure)
4. [Security](#security)
5. [About Gemini Protocol](#about-gemini-protocol)
6. [Contributing](#contributing)
7. [License](#license)
8. [Related Links](#related-links)

## Features

- Simple API for fetching Gemini content
- TLS certificate handling and validation
- Certificate fingerprint storage and verification
- Memory-safe implementation using V and C

## Installation

### Prerequisites

- V compiler
- OpenSSL development libraries
- C compiler

### Building

```bash
# Clone the repository
git clone ---
cd glv

# Build the project
v .
```

## Usage

Here's a simple example of how to use GLV:

```v
import gemini

fn main() {
    if result := gemini.fetch('gemini://midnight.pub/') {
        println('Status: ${result.code}')
        println('Meta: ${result.meta}')
        println('Body:\n${result.body.bytestr()}')
    } else {
        println('Fetch failed')
    }
}
```

### Response Structure

The `Response` struct contains:

- `code`: Status code from the server
- `meta`: Meta information from the response header
- `body`: Response body as bytes

## Security

GLV implements certificate validation and maintains a known hosts file (`~/.gemini_hosts`) to store and verify server certificates, similar to SSH's known_hosts mechanism.

## About Gemini Protocol

Gemini is a new internet protocol that:

- Sits between Gopher and the Web
- Emphasizes privacy, security, and simplicity
- Uses mandatory TLS
- Has a simple text-based content format

For more information:

- [Gemini Home](https://geminiprotocol.net/)
- [Gemini FAQ](https://geminiprotocol.net/docs/faq.gmi)

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related Links

- [Awesome Gemini](https://github.com/kr1sp1n/awesome-gemini)
- [V Programming Language](https://vlang.io/)
