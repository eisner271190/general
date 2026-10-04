# Cómo versionar

## Un solo número

`common` tiene **una** versión, `1.0.0`, literal, sin `${revision}` ni `-SNAPSHOT`. Aparece en dos
sitios y ambos deben moverse juntos:

1. `pom.xml` — `<version>` de `common-parent` (y el `<version>` del `<parent>` de los 4 módulos).
2. `common-bom/pom.xml` — las entradas de los módulos propios usan `${project.version}`, que el POM
   publicado resuelve al número del BOM.

Al no haber SNAPSHOT, lo que se instala con `mvn install` y lo publicado en CodeArtifact son las
mismas coordenadas: el microservicio resuelve sin sorpresas.

## Publicar una versión

1. Edita el número en `common/pom.xml` (y el `<parent><version>` de los módulos, o ejecuta
   `mvn versions:set -DnewVersion=X`).
2. Sustituye el endpoint de CodeArtifact si cambia de cuenta o región:

   ```bash
   mvn deploy -Depc.codeartifact.url="$(aws codeartifact get-repository-endpoint \
     --domain epc --repository common --format maven)"
   ```

   El endpoint no está hardcodeado en el repo a propósito. El token llega por variable de entorno:

   ```bash
   export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
     --domain epc --query token --output text)
   ```

3. Verifica que el BOM publicado tiene el número literal:

   ```bash
   mvn dependency:get -Dartifact=com.epc.common:common-bom:1.0.1:pom
   ```

4. Tag `v1.0.1` y push. El pipeline valida (`java-ci.yml`), publica (`mvn deploy`) y sube
   `epc/common-base:1.0.1` a ECR.

El `flatten-maven-plugin` es lo que hace que esto funcione: en modo `oss` publica los POM de los
módulos de código con sus dependencias y versiones resueltas, y `common-bom` usa modo `bom` para
publicar su `dependencyManagement` (con el modo por defecto el POM sale vacío y el BOM no gobierna
nada).

## Cambiar una versión de una dependencia

Se edita **un** fichero: `common-bom/pom.xml`.

- Si el artefacto lo gobierna un BOM importado (spring-*, aws-sdk, spring-cloud-aws), sube la
  propiedad `epc.*` del import correspondiente.
- Si no lo gobierna ningún import, cambia su entrada `epc.*` en el mismo fichero.

Después, Renovate abre en cada microservicio el PR que sube **una línea**: la `<version>` del
`import` de `common-bom`. El `pom.xml` del microservicio no vuelve a declarar ninguna versión de
terceros.

### Trampa al subir Spring Boot

`spring-boot-dependencies` se importa desde dos sitios: el `<parent>` del microservicio (que fija la
versión de los propios módulos de Boot) y `common-bom`. Una **entrada explícita** de
`dependencyManagement` gana siempre a un `import`, venga de donde venga. Medido: con el BOM en
`3.3.11` y el parent en `3.4.0`, el microservicio resuelve los módulos de Boot en `3.4.0` y el resto
(spring-core, micrometer) en las versiones del BOM.

Consecuencia práctica: **la versión de Boot del BOM debe coincidir con la del `<parent>`**. Si sube
Boot, suben los dos sitios; el sitio de referencia sigue siendo `common-bom/pom.xml`.