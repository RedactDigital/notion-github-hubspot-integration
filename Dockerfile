# https://bun.sh/guides/ecosystem/docker
# * -------------------- Base --------------------
# * Use `target base` if you are using docker compose locally
FROM oven/bun as base
ENV USER bun
ENV WORKDIR /usr/src/app
WORKDIR ${WORKDIR}

USER ${USER}
CMD [ "bun", "start" ]

# * -------------------- Install --------------------
# * Use `target install` if you are using docker compose for CI/CD tests, linting, etc.
FROM base as devInstall

# Set the user to root to avoid permission issues
USER root

# Install dependencies for development
# Using a temp directory will cache the dependencies and speed up future builds
RUN mkdir -p /temp/dev
COPY --chown=${USER}:${USER} package.json bun.lockb /temp/dev/
RUN cd /temp/dev && bun install --frozen-lockfile


# * -------------------- Install --------------------
FROM base as prodInstall
# Install dependencies for production
# Using a temp directory will cache the dependencies and speed up future builds
RUN mkdir /temp/prod
COPY --chown=${USER}:${USER} package.json bun.lockb /temp/prod/
RUN cd /temp/prod && bun install --production --frozen-lockfile

# * -------------------- Build --------------------
# Copy node modules from the temp directory to the build directory
FROM base as build
WORKDIR ${WORKDIR}

COPY --chown=${USER}:${USER} --from=prodInstall /temp/prod/node_modules ./node_modules
COPY --chown=${USER}:${USER} . .

RUN bun run build

# * -------------------- Release --------------------
# * Use `target release` if you are using for production
FROM build as release
ENV NODE_ENV=production

COPY --from=prodInstall /temp/prod/node_modules ./node_modules
COPY --from=build /usr/src/app/dist ./
COPY --chmod=700 --from=build /usr/src/app/entrypoint.sh ./entrypoint.sh

# ! Entrypoint script won't run without setting the ownership first
USER root
RUN chown -R ${USER}:${USER} ${WORKDIR}

# ! Set the user back to the bun user for security
USER ${USER}

ENTRYPOINT ["./entrypoint.sh"]
CMD ["bun", "start:production"]

