/** @type {import('next').NextConfig} */
module.exports = {
  reactStrictMode: false,
  experimental: { serverActions: { bodySizeLimit: '10mb' } },
};
