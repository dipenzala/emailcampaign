/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,

  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },

  // Ignore platform-specific valkey-glide binaries that BullMQ tries to load
  webpack: (config, { isServer }) => {
    config.resolve = config.resolve || {};
    config.resolve.alias = config.resolve.alias || {};

    config.resolve.alias['@valkey/valkey-glide'] = false;
    config.resolve.alias['@valkey/valkey-glide-linux-arm64-gnu'] = false;
    config.resolve.alias['@valkey/valkey-glide-linux-x64-gnu'] = false;
    config.resolve.alias['@valkey/valkey-glide-darwin-arm64'] = false;
    config.resolve.alias['@valkey/valkey-glide-darwin-x64'] = false;
    config.resolve.alias['@valkey/valkey-glide-win32-x64-msvc'] = false;

    config.resolve.fallback = {
      ...config.resolve.fallback,
      fs: false,
      net: false,
      tls: false,
    };

    // Ignore valkey modules in webpack
    config.ignoreWarnings = [
      ...(config.ignoreWarnings || []),
      /Can't resolve '@valkey\//,
      /Module not found.*valkey/i,
    ];

    return config;
  },

  experimental: {
    serverActions: { bodySizeLimit: '10mb' },
  },
  staticPageGenerationTimeout: 120,
};

module.exports = nextConfig;
