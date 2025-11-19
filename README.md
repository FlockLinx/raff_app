# RaffApp

Uma API REST para sorteios, construída em Elixir.

## Requisitos

- Elixir 1.14+
- Erlang/OTP 25+
- Mix

## Setup

Local
 - git clone repo
 - mix deps.get
 - mix test
 - mix run --no-halt

Docker
 - git clone
 - docker-compose up --build

A API estará disponível em ```http://localhost:4000```

## API endpoints

Usuarios

POST /users

```json
{
  "name": "João Silva",
  "email": "joao@email.com"
}
```

Sorteios

POST /raffles

```json
{
  "name": "Sorteio iPhone",
  "draw_date": "2024-01-15T20:00:00Z"
}
```

POST /raffles/:raffle_id/participate

```json
{
  "user_id": 123
}
```

GET /raffles/:raffle_id/result

```json
{
  "raffle_id": 1,
  "raffle_name": "Sorteio iPhone", 
  "winner": {
    "id": 123,
    "name": "João Silva",
    "email": "joao@email.com"
  }
}
```
POST /raffles/:raffle_id/draw

GET /raffles/:raffle_id/status

## Cobertura de testes

 - mix test --cover

Percentage | Module
-----------|--------------------------
    65.79% | RaffApp.Web.Router
    71.88% | RaffApp.RaffleParticipant
    75.76% | RaffApp.RaffleManager
    85.71% | RaffApp.RaffleParticipantSupervisor
    92.86% | RaffApp.RaffleScheduler
    95.24% | RaffApp.UserRegistry
   100.00% | RaffApp
   100.00% | RaffApp.Application
   100.00% | RaffApp.SingleWriterProcess
-----------|--------------------------
    76.50% | Total

## Melhorias

 - Refatoração
 
 - Aumentar cobertura de testes

 - Persistência em banco para durability

 - Clusterização para escalabilidade horizontal

 - Rate limiting e autenticação

 - Dashboard de monitoramento

 - WebSockets para notificaes em tempo real



Desenvolvido com 💚 e Elixir
