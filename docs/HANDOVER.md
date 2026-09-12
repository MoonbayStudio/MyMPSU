# MyMPSU handover checklist

The goal of handover is to let a group of MPGU students maintain the independent
service without depending on one former maintainer. Do not put passwords,
private keys, tokens or database dumps in this document or in Git.

## Recommended maintenance group

Assign at least two people with access to every critical service. Suggested
responsibilities:

- repository and release maintenance;
- backend and database operations;
- iOS and Android signing and publication;
- user support and privacy requests.

No critical account should depend on one student's personal email or phone
number. Use an organization-controlled address and document the recovery path.

## Access inventory

Record the current owner, backup owner and recovery procedure for:

- GitHub organization and repository;
- production server and SSH access;
- domain registrar and DNS;
- TLS/reverse-proxy configuration;
- Apple Developer and App Store Connect;
- Google Cloud OAuth and Google Play Console;
- SMTP provider and support mailboxes;
- monitoring and off-site backups;
- AI model host, if the assistant remains enabled.

Transfer access through each provider's team/organization features. Do not send
shared passwords in ordinary messages.

## Database decision

Transferring current user accounts is optional and is not required for project
continuity.

The preferred simple handover is:

1. deploy a new empty database;
2. configure new owner/admin email addresses;
3. let students create new accounts;
4. announce that old sessions and application data do not migrate.

If production data is ever transferred, treat the SQL dump as sensitive
personal data. Encrypt it, limit access, document the reason and delete temporary
copies after a verified restore. Follow `OPERATIONS.md` for backup and restore.

## Technical acceptance test

A maintainer who did not develop the project should perform this without verbal
instructions from the previous owner:

1. clone the repository on a clean machine;
2. configure `.env` from `.env.example`;
3. start PostgreSQL and the API;
4. receive a healthy response from `/health`;
5. inspect logs and create a database backup;
6. restore that backup into a disposable installation;
7. run backend tests and build the Android debug application;
8. explain how secrets and production access are recovered.

Record unclear or missing steps as GitHub issues. Handover is complete only when
this test succeeds without help from the outgoing maintainer.

## Before the outgoing maintainer leaves

- publish a tagged, known-good release;
- verify at least one off-site database backup or formally choose an empty DB;
- remove inactive personal access and add two current maintainers;
- enable two-factor authentication and recovery methods;
- transfer billing responsibility where applicable;
- document DNS records and server rebuild steps;
- publish a support contact students can continue using;
- schedule a recovery exercise with the new team.
