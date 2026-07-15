# orgz-setup-july26

Hands-on onboarding exercise for org z. Goal: get your machine set up, prove Docker works,
and run one real change through our actual GitOps flow (feature branch → PR → CI → CODEOWNERS
review → merge → auto-deploy to `staging` → manual-approved promote to `production`).

Nothing here is real infra — `production`/`staging` deploys are mocked (they just print a
message). The point is the *mechanics*, not the app.

## 0. Prereqs (before you can even clone this)

```sh
# install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install git gh
gh auth login
```

## 1. Clone and bootstrap your machine

```sh
gh repo clone dustinmays/orgz-setup-july26
cd orgz-setup-july26
./bootstrap.sh
```

`bootstrap.sh` installs `mise` (runtimes) and `colima` + `docker` (container runtime), then ends
with an integration test. **You should see a `Hello from Docker!` banner** as part of that test —
that's Docker/Colima proven to work on your machine. If any check fails, fix it and re-run the
script — it's safe to re-run as many times as you need.

## 2. Build and run this repo's container

The integration test above ran the generic Docker Hub `hello-world` image. Now build and run
*this repo's* image, which just prints `hello.txt`:

```sh
docker build -t orgz-hello .
docker run --rm orgz-hello
```

You should see the contents of `hello.txt` printed. Your name isn't in there yet — that's next.

## 3. Make a change through the real PR flow

1. Create a branch: `git checkout -b <yourname>/add-me`
2. Add your name to the contributor list in `hello.txt`
3. Rebuild and rerun the container (step 2) to confirm your change shows up locally
4. Commit, push, open a PR into `main`
5. Watch the `CI` check run (it rebuilds the Docker image in Actions)
6. Dustin reviews and approves (required — `main` is CODEOWNERS-gated)
7. Merge

## 4. Watch it deploy

Merging to `main` kicks off `deploy.yml`:
- `staging` deploys automatically — check the **Actions** tab, you'll see it complete in seconds
- `production` pauses for manual approval — check the **Environments** tab (or the Actions run) for
  a pending deployment. Dustin approves it, then it "ships."

Both deploy steps are mocked (just an `echo`), but the trigger, environment, and approval gate are
the same shape we'll use for real deploys later.

## Why this shape

This mirrors the flow decided for org z ventures generally: trunk-based (`feature/* → main` only,
no long-lived `dev` branch), build-once-promote-same-artifact through environments rather than
merging code twice, CODEOWNERS as the review gate, and a required-reviewer approval on
`production` only. See the team's onboarding repo for the full writeup.
