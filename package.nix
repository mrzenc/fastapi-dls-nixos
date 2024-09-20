{ pkgs }:
let
  pname = "fastapi-dls";
  version = "1.3.12";

  self = pkgs.python311Packages.buildPythonApplication {
    inherit pname version;
    src = pkgs.fetchFromGitLab {
      owner = "oscar.krause";
      repo = pname;
      rev = "6a54c05fbbe430ca6ee4260a1ab61099fab40a92";
      sha256 = "sha256-dBRdWic01r0w3Zkf6lwmJc+vPz9fwJ79UyCyjZAwnR4=";
      domain = "git.collinwebdesigns.de";
    };

    propagatedBuildInputs = with pkgs.python311Packages; [
      fastapi
      uvicorn
      python-jose
      pycryptodome
      python-dateutil
      sqlalchemy
      markdown
      python-dotenv
      cryptography
    ] ++ uvicorn.optional-dependencies.standard;

    doCheck = false;

    patches = [
      ./add-algorithms-argument.patch # fixes license activation
      ./readme-in-same-folder.patch # look for README.md in same folder as all scripts
    ];
    postPatch = ''
      mv README.md app/README.md
      # patch imports
      sed -i -E "s/^(\s*)(import|from) (util|orm)/\1\2 .\3/" app/main.py

      mv app fastapi_dls
    '';

    preBuild = ''
      # Script which checks certificates and runs the server itself
      cat > fastapi_dls/run.py << EOF
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from datetime import datetime, timezone, timedelta

import uvicorn
import os


def create_jwt_rsa_keys():
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )

    public_pem = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    private_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    open("/var/lib/fastapi-dls/instance.public.pem", "wb").write(public_pem)
    open("/var/lib/fastapi-dls/instance.private.pem", "wb").write(private_pem)


def create_ssl_certs():
    # https://gist.github.com/bloodearnest/9017111a313777b9cce5
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )
    name = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "${pname}")
    ])
    basic_constraints = x509.BasicConstraints(ca=True, path_length=0)
    now = datetime.now(timezone.utc)
    cert = (
        x509.CertificateBuilder()
          .subject_name(name)
          .issuer_name(name)
          .public_key(key.public_key())
          .serial_number(x509.random_serial_number())
          .not_valid_before(now)
          .not_valid_after(now + timedelta(days=100*365))
          .add_extension(basic_constraints, False)
          .sign(key, hashes.SHA256(), default_backend())
    )
    public_cert = cert.public_bytes(
        encoding=serialization.Encoding.PEM
    )
    private_cert = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    open("/var/lib/fastapi-dls/webserver.crt", "wb").write(public_cert)
    open("/var/lib/fastapi-dls/webserver.key", "wb").write(private_cert)


def main():
    # Check if certificates are present
    for i in ("instance.private.pem", "instance.public.pem",
              "webserver.key", "webserver.crt"):
        if os.path.isfile("/var/lib/fastapi-dls/" + i):
          continue

        # Create certificates
        create_jwt_rsa_keys()
        create_ssl_certs()
        break

    # Run app
    uvicorn.run("fastapi_dls.main:app",
      host=os.environ["DLS_URL"],
      port=int(os.environ["DLS_PORT"]),
      # TODO: add support for custom certs (e.g. Let's Encrypt)
      ssl_keyfile="/var/lib/fastapi-dls/webserver.key",
      ssl_certfile="/var/lib/fastapi-dls/webserver.crt",
      proxy_headers=True)
EOF

      # fastapi-dls doesn't include pyproject.toml nor setup.py
      cat > setup.py << EOF
from setuptools import setup

setup(
    name='${pname}',
    version='${version}',
    packages=[("fastapi_dls")],
    package_data={"fastapi_dls": ["README.md"]},
    include_package_data=True,
    entry_points={
        'console_scripts': [
            'fastapi-dls = fastapi_dls.run:main',
        ]
    }
)
EOF
    '';
  };
in
self