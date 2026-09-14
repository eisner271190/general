# Endpoint /exchange - Intercambio de Código de Autorización por Tokens

## Descripción General

Este endpoint implementa el flujo de intercambio de código de autorización (Authorization Code Flow) con PKCE para AWS Cognito. Permite intercambiar un código de autorización temporal por tokens de acceso completos.

## Endpoint

```
POST /api/v1/auth/exchange
```

## Request Body

```json
{
  "code": "abc123...",
  "code_verifier": "xyz789...",
  "redirect_uri": "myapp://auth/callback"
}
```

### Campos

- **code** (String, requerido): Código de autorización devuelto por Cognito después del login
- **code_verifier** (String, requerido): Verificador PKCE utilizado en la solicitud inicial de autorización
- **redirect_uri** (String, requerido): URI de redirección que debe coincidir con la utilizada en la solicitud inicial

## Response

### Éxito (200 OK)

```json
{
  "data": {
    "accessToken": "eyJraWQiOiI...",
    "idToken": "eyJraWQiOiI...",
    "refreshToken": "eyJjdHkiOiJ...",
    "expiresIn": 3600,
    "tokenType": "Bearer"
  },
  "message": "Código intercambiado exitosamente",
  "statusCode": 200
}
```

### Error (400 Bad Request)

```json
{
  "data": null,
  "message": "Error al intercambiar el código",
  "statusCode": 400,
  "error": "Invalid authorization code"
}
```

## Flujo Completo de Autenticación

1. **Usuario inicia login**: La app Flutter redirige al usuario a Cognito
2. **Cognito devuelve código**: Después de autenticarse, Cognito devuelve un `code` a través del redirect_uri
3. **App envía código al backend**: Flutter llama a `/api/v1/auth/exchange` con el código
4. **Backend intercambia código**: El backend llama al endpoint `/oauth2/token` de Cognito
5. **Cognito devuelve tokens**: Cognito valida el código y devuelve los tokens
6. **Backend retorna tokens**: El backend envía los tokens a la app Flutter
7. **App guarda tokens**: Flutter almacena los tokens de forma segura (ej: flutter_secure_storage)

## Variables de Entorno Requeridas

```bash
AWS_COGNITO_DOMAIN=your-cognito-domain.auth.region.amazoncognito.com
AWS_COGNITO_USER_POOL_CLIENT_ID=your-client-id
AWS_COGNITO_USER_POOL_ID=region_XXXXXXXXX
```

## Componentes Implementados

### 1. DTOs (Data Transfer Objects)
- **ExchangeRequestDTO**: Solicitud con code, code_verifier y redirect_uri
- **ExchangeResponseDTO**: Respuesta con accessToken, idToken, refreshToken, expiresIn y tokenType

### 2. Modelos de Dominio
- **ExchangeRequest**: Modelo de dominio para la solicitud
- **ExchangeResponse**: Modelo de dominio para la respuesta

### 3. Mappers
- **ExchangeRequestMapperDto**: Mapeo entre DTO y modelo de dominio
- **ExchangeResponseMapperDto**: Mapeo entre modelo de dominio y DTO

### 4. Arquitectura Hexagonal

#### Puerto de Entrada (Service Port)
- **ExchangeServicePort**: Define el contrato del caso de uso

#### Caso de Uso
- **ExchangeUseCase**: Implementa la lógica del caso de uso

#### Puerto de Salida
- **ExchangePort**: Define el contrato para el adaptador

#### Adaptador
- **ExchangeAdapter**: Implementa la comunicación con CognitoClient

#### CognitoClient
- **exchangeCodeForTokens()**: Método que realiza la llamada HTTP al endpoint `/oauth2/token` de Cognito

### 5. Controlador
- **AuthController**: Endpoint REST `/api/v1/auth/exchange`

## Seguridad

- Utiliza PKCE (Proof Key for Code Exchange) para proteger el flujo de autorización
- El código de autorización es de un solo uso y tiene un tiempo de vida corto
- Los tokens deben almacenarse de forma segura en el cliente
- El refresh_token permite obtener nuevos access_tokens sin reautenticación

## Ejemplo de Uso desde Flutter

```dart
Future<TokenResponse> exchangeCode(String code, String codeVerifier, String redirectUri) async {
  final response = await http.post(
    Uri.parse('https://your-api.com/api/v1/auth/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': code,
      'code_verifier': codeVerifier,
      'redirect_uri': redirectUri,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body)['data'];
    // Guardar tokens de forma segura
    await secureStorage.write(key: 'access_token', value: data['accessToken']);
    await secureStorage.write(key: 'id_token', value: data['idToken']);
    await secureStorage.write(key: 'refresh_token', value: data['refreshToken']);
    
    return TokenResponse.fromJson(data);
  } else {
    throw Exception('Failed to exchange code');
  }
}
```

## Dependencias Maven Requeridas

```xml
<!-- Spring WebFlux para WebClient -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>

<!-- AWS Cognito SDK -->
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>cognitoidentityprovider</artifactId>
</dependency>

<!-- Validation -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

## Notas Adicionales

- El `expiresIn` indica el tiempo de vida del access_token en segundos (generalmente 3600 = 1 hora)
- El `id_token` contiene información del usuario (claims) en formato JWT
- El `access_token` se usa para autorizar llamadas a APIs protegidas
- El `refresh_token` se usa para obtener nuevos tokens cuando el access_token expira
