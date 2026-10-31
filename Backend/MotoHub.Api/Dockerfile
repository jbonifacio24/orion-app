# syntax=docker/dockerfile:1.7
FROM mcr.microsoft.com/dotnet/sdk:8.0.408 AS restore
WORKDIR /src
COPY . .
RUN --mount=type=cache,id=motohub-nuget,target=/root/.nuget/packages \
    dotnet restore Backend/MotoHub.Api/MotoHub.Api.csproj --disable-parallel

FROM restore AS publish
RUN --mount=type=cache,id=motohub-nuget,target=/root/.nuget/packages \
    dotnet publish Backend/MotoHub.Api/MotoHub.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM restore AS migrator
RUN --mount=type=cache,id=motohub-nuget,target=/root/.nuget/packages \
    dotnet tool install --tool-path /tools dotnet-ef --version 8.0.18
ENV PATH="/tools:${PATH}"
ENTRYPOINT ["dotnet-ef"]

FROM mcr.microsoft.com/dotnet/aspnet:8.0.15 AS runtime
WORKDIR /app
COPY --from=publish /app/publish .
RUN mkdir -p /data/product-images && chown -R "$APP_UID:$APP_UID" /data/product-images
ENV ASPNETCORE_HTTP_PORTS=8080
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "MotoHub.Api.dll"]