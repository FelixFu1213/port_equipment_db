FROM node:20-bullseye-slim AS build

ENV HUSKY=0 \
    CI=true

WORKDIR /app

RUN npm install -g pnpm@9.15.4

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

# 图片压缩依赖平台二进制，构建时关闭以保证可移植性
ENV ENABLE_IMAGEMIN=false

RUN pnpm exec vite build --config ./config/vite.config.prod.ts

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
