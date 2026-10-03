/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },
  experimental: { serverActions: { bodySizeLimit: '10mb' } },
  staticPageGenerationTimeout: 120,
};
module.exports = nextConfig;
