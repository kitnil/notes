Check this
==========
SSL Guidelines

CSR
---
Certificate signing request
public key with parameters, which identifies sender

CA
--
Certificate authority (Удостоверяющий центр).

Подписывает CSR своим приватным ключом, выпуская сертификат пользователя (peer'a).

CRL
---
Certificate revocation list

* list of series numbers with blacklist certificates
* reason (about 6 reasons)
* hold (приостановление действия сертификата).

Cons:
* CRL is offline.

OCSP
----
Online certificate status protocol (проверка валидности сертификата в режиме реального времени).

Other
-----
ROOT Certificates

Applications
------------
linux: cearufus
