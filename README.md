# AI Test Benchmark

Quick test commands:
- JavaScript: `cd benchmarks/javascript/lodash-subset && npm test`
- Python: `cd benchmarks/python/custom-functions && pytest`

## Java

```bash
cd benchmarks/java/commons-subset
mvn test
mvn jacoco:report
open target/site/jacoco/index.html
```
## Projects

Projects can be added under the "benchmarks" folder under their respective language. Project templates must be created in order to ensure the functionality for generating test reports works.

## Docker Setup

Docker can optionally be set-up depending on your needs, but a local machine should be sufficient enough. A Dockerfile and docker-compose.yml is provided