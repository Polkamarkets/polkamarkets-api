# Polkamarkets API

Polkamarkets is an Autonomous Prediction Market Protocol built for cross-chain information exchange and trading, based on Polkadot.

## Project Setup

### 1. Required software

- [Ruby](https://github.com/rbenv/rbenv) (`ruby 2.6.6 with rbenv`)

Databases:
- [Postgres](https://www.postgresql.org/)
- [Redis](https://redis.io/)

To allow env vars to be used in ruby:
- [Direnv](https://direnv.net/)

### 2. Installing the app 

```
git clone git@github.com:Polkamarkets/polkamarkets-api.git
cd polkamarkets-api
```

- Create `.envrc` file with env vars  

```
direnv allow
bundle install
rails db:create
rails db:migrate
rails markets:check_new_markets # syncs data from smart contract to local database
```

### 3. Running the app

```
rails s
```
