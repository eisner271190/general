# Configuración del generator

El generator lee la configuración inicial de la aplicación, sus ambientes y sus microservicios. Cada microservicio selecciona los componentes que necesita; los componentes definen la estructura y los templates; el ambiente define los valores; el plan contiene el resultado final.

```text
target/<app>/<app>.json + components/*.json + templates
    -> generation-plan.json
```

Todos los paths son relativos al directorio de salida.

## 1. JSON inicial: configuración de la aplicación

Vive en `target/<applicationId>/<applicationId>.json`. El generator escanea cada subcarpeta de `target/` y carga sus `*.json` de primer nivel (excluye `target/output/`).

Define el nombre e identificador de la aplicación, sus ambientes y los microservicios que se deben crear.

```json
{
  "applicationName": "Quiz Smart",
  "applicationId": "com.quizsmart.app",
  "environments": [
    {
      "name": "develop",
      "variables": [
        {
          "key": "DATABASE_URL",
          "value": "localhost"
        },
        {
          "key": "DEBUG",
          "value": "true"
        }
      ]
    }
  ],
  "microservices": [
    {
      "name": "quiz-api",
      "backend": "dotnet9.json",
      "deploy": "docker",
      "entities": [
        {
          "name": "Quiz",
          "fields": [
            {
              "name": "id",
              "datatype": "Guid"
            },
            {
              "name": "title",
              "datatype": "string"
            }
          ],
          "relations": [
            {
              "entity": "Question",
              "type": "one-to-many"
            }
          ]
        },
        {
          "name": "Question",
          "fields": [
            {
              "name": "id",
              "datatype": "Guid"
            },
            {
              "name": "text",
              "datatype": "string"
            },
            {
              "name": "quizId",
              "datatype": "Guid"
            }
          ],
          "relations": [
            {
              "entity": "Quiz",
              "type": "many-to-one"
            },
            {
              "entity": "Answer",
              "type": "one-to-many"
            }
          ]
        },
        {
          "name": "Answer",
          "fields": [
            {
              "name": "id",
              "datatype": "Guid"
            },
            {
              "name": "text",
              "datatype": "string"
            },
            {
              "name": "questionId",
              "datatype": "Guid"
            },
            {
              "name": "isCorrect",
              "datatype": "boolean"
            }
          ],
          "relations": [
            {
              "entity": "Question",
              "type": "many-to-one"
            }
          ]
        }
      ],
      "endpoints": [
        "GET /quizzes",
        "POST /quizzes"
      ],
      "port": 5000
    }
  ]
}
```

### Propiedades del JSON de configuración

- `applicationName`: nombre de la aplicación.
- `applicationId`: identificador único de la aplicación, por ejemplo `com.quizsmart.app`.
- `environments`: array de ambientes. Cada ambiente tiene un `name` y un array `variables` de objetos `key`/`value`.
- `microservices`: array de microservicios que se deben crear.
- `microservices[].backend`: nombre del JSON de backend que se debe cargar desde `components/backend/`. Por ejemplo, `dotnet9.json` se resuelve como `components/backend/dotnet9.json`.
- `microservices[].deploy`: estrategia o destino de despliegue como string.
- `microservices[].entities`: array de entidades. Cada entidad tiene `name`, `fields` y `relations`; no necesita `datatype` porque todas representan objetos.
- `microservices[].entities[].fields`: array de campos, cada uno con `name` y `datatype`.
- `microservices[].entities[].relations`: relaciones con otras entidades del mismo microservicio.
- `microservices[].endpoints`: array de endpoints como strings.
- `microservices[].port`: puerto del microservicio.

## 2. Componentes

El proyecto debe tener una carpeta `components` con una subcarpeta para cada tipo de componente:

```text
components/
├── backend/
│   ├── dotnet9.json
│   └── ...
├── frontend/
│   ├── react.json
│   └── ...
└── cloud/
    ├── docker.json
    └── ...
```

Cada subcarpeta contiene los JSON de sus variantes. Por ejemplo, `backend/dotnet9.json` define la estructura de un backend .NET 9.

## 2.1. JSON del componente: `components/backend/dotnet9.json`

Define las carpetas, los archivos y los archivos predeterminados del componente. En `files`, `key` es el path del archivo de salida y `value` es el path del template que se debe usar. El template puede contener placeholders.

```json
{
  "name": "dotnet9",
  "type": "backend",
  "directories": [
    "backend",
    "backend/src",
    "backend/src/Domain"
  ],
  "files": [
    {
      "key": "backend/src/Domain/User.cs",
      "value": "templates/backend/src/Domain/User.cs"
    },
    {
      "key": "backend/appsettings.json",
      "value": "templates/backend/appsettings.json"
    }
  ],
  "defaultFiles": [
    "defaults/backend/.gitignore"
  ]
}
```

En este ejemplo, `templates/backend/appsettings.json` podría contener:

```json
{
  "ApiUrl": "{{API_URL}}",
  "DatabaseName": "{{DATABASE_NAME}}"
}
```

## 3. Transformación a `generation-plan.json`

El generator procesa cada microservicio de la configuración y resuelve sus componentes. Para el ejemplo anterior:

```text
microservice.backend = dotnet9.json
  -> components/backend/dotnet9.json
  -> templates/backend/*
  -> variables del ambiente develop
```

El JSON del componente aporta `directories`, `files` y `defaultFiles`. Para cada archivo, el generator lee el template indicado por `files[].value`, reemplaza sus placeholders con las variables del ambiente seleccionado y coloca el contenido final en el plan.

El flujo completo es:

```text
target/<app>/<app>.json
  -> seleccionar microservicio y ambiente
  -> resolver components/backend/dotnet9.json
  -> cargar templates
  -> reemplazar placeholders
  -> generation-plan.json
```

## 4. Variables del ambiente

Las variables pertenecen al ambiente correspondiente dentro de la configuración. Se usan para resolver los placeholders de los templates. No definen carpetas ni archivos.

```json
[
  {
    "key": "API_URL",
    "value": "https://api-dev.example.com"
  },
  {
    "key": "DATABASE_NAME",
    "value": "myapp_dev"
  }
]
```

Con estos valores, `{{API_URL}}` se reemplaza por `https://api-dev.example.com` y `{{DATABASE_NAME}}` por `myapp_dev`.

## 5. Generation plan: `generation-plan.json`

Es el resultado concreto que se va a generar. Sus `files` ya contienen el contenido final, por lo que aquí no deben quedar placeholders.

```json
{
  "project": "Quiz Smart",
  "environment": "develop",
  "directories": [
    "backend",
    "backend/src",
    "backend/src/Domain"
  ],
  "files": [
    {
      "key": "backend/src/Domain/User.cs",
      "value": "namespace Backend.Domain;\n\npublic sealed class User\n{\n    public required string Id { get; init; }\n}\n"
    },
    {
      "key": "backend/appsettings.json",
      "value": "{\n  \"ApiUrl\": \"https://api-dev.example.com\",\n  \"DatabaseName\": \"myapp_dev\"\n}\n"
    }
  ],
  "defaultFiles": [
    "defaults/backend/.gitignore"
  ]
}
```

El plan indica exactamente qué debe hacer el executor:

- crear las carpetas de `directories`;
- crear cada archivo de `files`, usando `key` como destino y `value` como contenido;
- copiar los archivos de `defaultFiles`.

Antes de ejecutarlo, se deben validar los paths, evitar duplicados y comprobar que no haya placeholders sin resolver.
