#!/usr/bin/env python3
"""Create a LAN HTTPS test certificate. Does not install trust in any browser/OS."""
import argparse
import ipaddress
import os
from pathlib import Path
import shutil
import subprocess


def run(*arguments):
    subprocess.run(["openssl", *map(str, arguments)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip", required=True, type=ipaddress.IPv4Address)
    args = parser.parse_args()
    if not shutil.which("openssl"):
        parser.error("OpenSSL is required on the machine generating the certificate")
    root = Path(__file__).resolve().parents[2]
    private = Path.home() / ".local" / "share" / "projectmine-web" / "certs"
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Keys are never placed in the exported website, ZIP or source repository.
    old_mask = os.umask(0o077)
    try:
        ca_key = private / "ca.key"
        ca_cert = private / "ca.crt"
        if ca_key.exists() != ca_cert.exists():
            parser.error("Incomplete existing CA; refusing to replace an existing trust identity")
        if not ca_key.exists():
            run("req", "-x509", "-newkey", "rsa:2048", "-sha256", "-days", "365", "-nodes",
                "-keyout", ca_key, "-out", ca_cert,
                "-subj", "/CN=ProjectMine LAN Test CA",
                "-addext", "basicConstraints=critical,CA:TRUE,pathlen:0",
                "-addext", "keyUsage=critical,keyCertSign,cRLSign")
        extension = private / "server.ext"
        extension.write_text(
            "basicConstraints=critical,CA:FALSE\n"
            "keyUsage=critical,digitalSignature,keyEncipherment\n"
            "extendedKeyUsage=serverAuth\n"
            f"subjectAltName=IP:{args.ip},IP:127.0.0.1,DNS:localhost\n"
            "authorityKeyIdentifier=keyid,issuer\n")
        run("req", "-new", "-newkey", "rsa:2048", "-nodes",
            "-keyout", private / "server.key", "-out", private / "server.csr",
            "-subj", "/CN=ProjectMine LAN Server")
        run("x509", "-req", "-in", private / "server.csr",
            "-CA", ca_cert, "-CAkey", ca_key, "-CAcreateserial",
            "-out", private / "server.crt", "-days", "90", "-sha256", "-extfile", extension)
    finally:
        os.umask(old_mask)
    public = root / "dist" / "ProjectMine-local-CA.crt"
    public.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ca_cert, public)
    public.chmod(0o644)
    fingerprint = subprocess.check_output(
        ["openssl", "x509", "-in", str(ca_cert), "-noout", "-fingerprint", "-sha256"], text=True)
    print(f"Public CA for client import: {public}\n{fingerprint.strip()}")
    print(f"Server certificate is valid for {args.ip}, 127.0.0.1 and localhost for 90 days.")
    print("No certificate was installed in any trust store. Copy only the public .crt to clients.")
    print("Start: python3 tools/web/serve.py --https --host 0.0.0.0 --no-open")


if __name__ == "__main__":
    main()
