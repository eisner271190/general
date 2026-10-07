# Cómo migrar un microservicio

## 1. `pom.xml`

**Conserva tu `<parent>`** (por ejemplo `spring-boot-starter-parent`) y añade el import del BOM.
Quita el `<dependencyManagement>` que importaba `software.amazon.awssdk:bom`: ya viene dentro.

```xml
<properties>
  <java.version>17</java.version>
  <!-- Solo si NO los gobierna spring-boot-starter-parent -->
  <maven.compiler.plugin.version>3.14.0</maven.compiler.plugin.version>
  <jacoco>0.8.12</jacoco>
</properties>

<dependencyManagement>
  <dependencies>
    <!-- Linea única de gobierno de versiones -->
    <dependency>
      <groupId>com.epc.common</groupId>
      <artifactId>common-bom</artifactId>
      <version>1.0.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <!-- Sin versión: la pone common-bom. Arrastra common-error y common-log -->
  <dependency>
    <groupId>com.epc.common</groupId>
    <artifactId>common-web</artifactId>
  </dependency>
</dependencies>
```

Borra todas las `<version>` de dependencias de terceros que est governs el BOM. **Se quedan** las de
los plugins y solo esas, porque un `import` de BOM no aporta `pluginManagement`:

| Se queda en el ms | Por qué |
| --- | --- |
| `maven-compiler-plugin`, `maven-dependency-plugin`, `jacoco-maven-plugin`, `pitest-maven`, `sonar-maven-plugin`, `native-maven-plugin` | Versiones de plugins: ningún BOM las gobierna y el ms solo puede tener un `<parent>`, que ya es el de Boot |
| `java.version`, `maven.compiler.source/target`, `skipTests` | No son versiones de dependencias |

Medido en `quizapi`: los `annotationProcessorPaths` **sí** resuelven desde el `dependencyManagement`,
así que ahí no hay que declarar versión.

## 2. Código

Borra tu `GlobalExceptionHandler`, tu excepción de negocio y tus clases de respuesta, y cambia los
imports:

```java
import com.epc.common.error.ApiResponse;
import com.epc.common.error.CommonException;   // antes GeneralException
```

El contrato no cambia: mismos nombres de getters, mismos códigos, mismo cuerpo. El único cambio es
que `timestamp` se genera en UTC (sigue siendo `LocalDateTime`, sin offset en el JSON) y que la clave
`stackTrace` ya no aparece en las respuestas de error.

Los **tests que importaban las clases borradas** hay que cambiarlos a mano.

## 3. Imagen

`common/docker/Dockerfile` es una imagen de **runtime**: la compilación ocurre fuera de Docker.

```bash
mvn -B compile dependency:copy-dependencies -DincludeScope=runtime
docker build -t mi-ms .
```

`Dockerfile` del microservicio, 4 líneas:

```dockerfile
FROM <cuenta>.dkr.ecr.<region>.amazonaws.com/epc/common-base:1.0.0
COPY target/classes ${LAMBDA_TASK_ROOT}
COPY target/dependency/* ${LAMBDA_TASK_ROOT}/lib/
CMD [ "com.example.Application::handleRequest" ]
```

### Snippets

`.dockerignore` mínimo (**sin `target/`**: el contexto necesita `target/classes` y
`target/dependency/`):

```
.git
logs
postman
.idea
bootstrap
```

`.gitignore` (bloque Java):

```
target/
.idea/
*.iml
.flattened-pom.xml
```

`settings.xml` (plantilla completa en `common/settings.xml`):

```xml
<settings>
  <servers>
    <server>
      <id>codeartifact</id>
      <username>aws</username>
      <password>${env.CODEARTIFACT_AUTH_TOKEN}</password>
    </server>
  </servers>
  <profiles>
    <profile>
      <id>codeartifact</id>
      <repositories>
        <repository>
          <id>codeartifact</id>
          <url>https://epc-<cuenta>.d.codeartifact.<region>.amazonaws.com/maven/common/</url>
        </repository>
      </repositories>
    </profile>
  </profiles>
  <activeProfiles><activeProfile>codeartifact</activeProfile></activeProfiles>
</settings>
```

## 4. Actualización del `import`

Cuando haya un `common-bom` nuevo, el tag `v*` de `common` arranca el trigger de plataforma
(`library/platform/scripts/bump-bom-version.py`): sube **una línea** —la `<version>` del `import`—
en todos los `pom.xml` del microservicio y abre un único pull request. No hay nada que configurar
en el microservicio ni credenciales que sembrar.

Actualizar las versiones de terceros del BOM es cosa de una persona: se edita
`common/common-bom/pom.xml` y se publica una release.

## 5. Comprobaciones

```bash
mvn -o dependency:tree | grep -c 'com.epc.common'   # common-web + common-error + common-log
mvn -o test-compile                                 # debe compilar sin <version> locales
```