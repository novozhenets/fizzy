# Fizzy

## Setting up for development

First get everything installed and configured with:

    bin/setup

If you'd like to load fixtures:

    bin/rails db:fixtures:load

And then run the development server:

    bin/dev

You'll be able to access the app in development at http://development-tenant.fizzy.localhost:3006

## Running tests

For fast feedback loops, unit tests can be run with:

    bin/rails test

The full continuous integration tests can be run with:

    bin/ci

## Working with AI features

To work on AI features you need the OpenAI API key stored in the development's credentials file. To decrypt the credentials,
you need place the key in a file `config/credentials/development.key`. You can copy the file from One Password in
"Fizzy - development.key".

To get semantic searches working for existing data you need to calculate all the vector embeds:

```ruby
Card.find_each(&:refresh_search_embedding)
Comment.find_each(&:refresh_search_embedding)
```

### Tests

#### AI Requests

For testing OpenAI API requests, we use [VCR](https://github.com/vcr/vcr). If you want to test AI features exercising the API, you need to place the `config/credentials/test.key`
that you can get from 1Password in "Fizzy - test.key". Then, when running tests that use Open AI API, you must either set the env variable `VCR_RECORD=1`
or to add `vcr_record!` to the test. See `VcrTestHelper`. Due to Open AI quotas, you may need to limit the parallelization. E.g: `PARALLEL_WORKERS=2`

You can regenerate all the VCR fixtures with:

```bash
VCR_RECORD=1 PARALLEL_WORKERS=2 bin/rails test
```

A typical scenario is making modifications LLM prompts. You need to:

1. Make the prompt changes.
2. Run the test with `VCR_RECORD=1` set.
3. Make sure that the test passes by running the test normally (without setting VCR_RECORD=1).
4. Commit the YML fixtures that VCR has generated. That way, the next time you run the test, it will run fast without performing any request.

Notice that if you pass changing data to the prompt, this mechanism won't work. E.g: if you pass data timestamps.
You need to make sure those timestamps are always the same across executions.

## Environments

Fizzy is deployed with Kamal. You'll need to have the 1Password CLI set up in order to access the secrets that are used when deploying. Provided you have that, it should be as simple as `bin/kamal deploy` to the correct environment.

### Beta

Beta is primarily intended for testing product features.

Beta tenant is:

- https://fizzy.37signals.works/

This environment uses local disk for Active Storage.


### Staging

Staging is primarily intended for testing infrastructure changes.

Production tenants are:

- https://37s.fizzy.37signals-staging.com/
- https://dev.fizzy.37signals-staging.com/
- https://qa.fizzy.37signals-staging.com/

This environment uses a FlashBlade bucket for blob storage, and shares nothing with Production. We may periodically copy data here from production.


### Production

Production tenants are:

- https://37s.fizzy.37signals.com/
- https://dev.fizzy.37signals.com/
- https://qa.fizzy.37signals.com/

This environment uses a FlashBlade bucket for blob storage.
