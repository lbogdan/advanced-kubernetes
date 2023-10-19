# Useful `kubeseal` (Sealed Secrets) Commands

Fetch the public certificate (which you can save to a file and use subsequently to encrypt with `--cert $CERT_FILE`):

```sh
kubeseal --fetch-cert [>kubeseal.pem]
# output:
# -----BEGIN CERTIFICATE-----
# MIIEzTCCArWgAwIBAgIRALSiGgBTlafEL1Ih3koeD8QwDQYJKoZIhvcNAQELBQAw
# ADAeFw0yMzEwMTQwOTQ5MDlaFw0zMzEwMTEwOTQ5MDlaMAAwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQC61aujwWYSJM/R68uFo9z125bEd0EnJekM6nRB
# [...]
# -----END CERTIFICATE-----
```

Encrypt a secret `.yaml` file to a sealed secret `.yaml` file:

```sh
kubeseal -o yaml [--cert $CERT_FILE] <$SECRET_FILE >$SEALEDSECRET_FILE
# e.g.
kubectl create secret generic test --from-literal username=someuser --from-literal password=somepassword --dry-run=client -o yaml >secret.yaml
kubeseal -o yaml <secret.yaml >sealedsecret.yaml
cat sealedsecret.yaml
# output:
# apiVersion: bitnami.com/v1alpha1
# kind: SealedSecret
# metadata:
#   creationTimestamp: null
#   name: test
#   namespace: default
# spec:
#   encryptedData:
#     password: AgBdl9RKZmnEKC09TL1rHn3QU5XgRN/LTkZ1IiTn5J1tM4Q+8in0wn7YFzNrgd4Z5ejFYfUUjrIA3vW5bRpKeVw9ijUWEkW1ctUPXSZUrXLNFi7rzBooDT7xmfrG6nxxvD23UmVmbT1A2JHAnG5yVtEqMTunUxtqzxlvS7WKbgNVi1AzMH0gdSe0jOzX60oCuIv0/uEIleRwEbfpmB2GupeIAWbBRty2e47igiRzd4/XpIZS+WCN4shntIcEjSDm5AFKIQY4JhikwkhSO4viC8Gr87eo5fGtkbDH+ANLKW8WjXTBvefENR6TjweahvIcSRCZqfKxrHVuFiGYInkDYF0A1w/nsQBqMSVcixadADOsF9vzV7B099gNwuc6lafwDK0Py6TsL6uN+JLiQ1GHTjhBCE8jdJGp7eR5tn0aw7/UJ/1vua2rSSbn20SHP+8vBESSCgBMtKt0ntzjzOzlZfD+67zdOim+OLdvDY20XvsiP2572nBn5XI+KE0fpjdCyXzEphYEocuzgziaJE0lJfJliNsO4desVylbz5d1SsXBvtiuAsNhW4ufsGnO5sp5o5PWoIo5Ov4erV15CK3I+kQDccwzbmfSIhPXhZjde5F6/k9r4JNbIqxh02VTrlkw55w5xx1UJSqQp6orFgqkkbuCVcvJVl+Zg8lgio51u19rNgTLIb1n4ELhaZ4JhiYDn9RsP31BTTTEgLbqrFk=
#     username: AgCspO1Q1O/rSwgJjTRAaxq5yQ/11lfZF8Nhch27JV443o5h12DwLcESVtgZiboBR07DHmUy/o++iy7RSadpPU1yWyURHZOwx37GQPa+ND0tDIsObrnirLifg7hhGFCQwNZwDDejGQmvV7m/9PemMAQsQtM5gXdHY3NxtUquFDBrnquYXxfqCJC9I3GBYSgoIKJfnkXrvJBqlsCDuFr72FU1Q0XAzEpt6SfZTJGeIkEVYp6ivfzzBPhzbWOl+PEvSOOoFp47zMkrtSHVD1JCe9320/DSBPm1jD+JCEDW3ZPmL16tWLgj/hdW37EKMtStg+ctPe+AVxI2681QZ16nbC6cC9Vjy/g/6CNmXGCV8+cICu6YcNhTaL5neBbIUh1mDR/6xfpkmPiYgh2ytSDIjvQGqf7DH6dGBYXIa33aSEE42X68Qji1+rTXXELCTvHWMLazhq+YpSeWSIKASGaRmFukl3y6FlGrLhYuIVVeNExSf1Bb2QWeCa1AGObR26Yt+M/RA7cnbP8w0OrUFyRrL9L9d3PdWv8RIT2B/IelbOfywt/0azGBL/uHCa6JuLf4uNtYy4HGXH8/38YgPr+4YWcPhox36mGBAhYy9IQtg3RlIG7CLBrEL/Dvuod1OLk8zd81DegbKOjxODD/2qyM8H8IUfTZVRcJqmXFR6LogTwNDll5Gu1oC/ehQEw+Ki/CK6H+fW8HFumJ/w==
#   template:
#     metadata:
#       creationTimestamp: null
#       name: test
#       namespace: default
```

Raw encrypt a secret string:

```sh
# write the secret to secret.txt
cat secret.txt | tr -d '\r\n' | kubeseal --raw --name $SECRET_NAME [--namespace $NAMESPACE] [--cert $CERT_FILE]
```

> **Note**
>
> This can only be used to create a secret with the specified name``, in the specified namespace.

Raw encrypt a secret string (namespace-wide):

```sh
# write the secret to secret.txt
cat secret.txt | tr -d '\r\n' | kubeseal --raw --scope namespace-wide [--namespace $NAMESPACE] [--cert $CERT_FILE]
```

> **Note**
>
> This can only be used to create a secret in the specified namespace, with any name. The sealed secret needs to have the `sealedsecrets.bitnami.com/namespace-wide: "true"` annotation.

Raw encrypt a secret string (cluster-wide):

```sh
# write the secret to secret.txt
cat secret.txt | tr -d '\r\n' | kubeseal --raw --scope cluster-wide [--cert $CERT_FILE]
```

> **Note**
>
> This can be used to create a secret in any namespace, with any name. The sealed secret needs to have the `sealedsecrets.bitnami.com/cluster-wide: "true"` annotation.

Validate a sealed secret:

```sh
kubeseal --validate <$SEALEDSECRET_FILE
```

More details [here](https://github.com/bitnami-labs/sealed-secrets#sealed-secrets-for-kubernetes).
