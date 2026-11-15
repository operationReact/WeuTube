FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 weutube
WORKDIR /app
COPY --chown=weutube:weutube app.jar /app/app.jar
USER weutube
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=70.0","-jar","/app/app.jar"]
