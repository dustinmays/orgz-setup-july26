---
name: Onboarding exercise task
about: Your hands-on task for this repo
title: "[exercise] Add your name via a PR"
labels: exercise
assignees: ""
---

## Task

1. Follow `README.md` steps 0–2 (machine setup, Docker sanity check, build this repo's image).
2. Follow step 3: branch, add your name to `hello.txt`, open a PR into `main`.
3. Follow step 4: watch the merge trigger a `staging` deploy, then watch `production` wait for
   approval.

## Done when

- [ ] `./bootstrap.sh` integration test passes on your machine
- [ ] `docker run --rm orgz-hello` prints `hello.txt` locally
- [ ] Your PR is merged into `main`
- [ ] You've seen the `staging` deploy complete and the `production` deploy pause for approval in
      the Actions tab
