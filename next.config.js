/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
];

module.exports = {
  reactStrictMode: false,
  experimental: {
    serverActions: { bodySizeLimit: '10mb' },
  },
  // Ignore optional bullmq deps (valkey-glide, etc.)
  webpack: (config, { isServer }) => {
    if (isServer) {
      config.externals = config.externals || [];
      const externals = ['@valkey/valkey-glide', 'ioredis', 'bullmq'];
      config.externals.push(...externals);
    }
    return config;
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
};
