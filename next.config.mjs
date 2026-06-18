/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false, 
  output: 'standalone',
  images: {
    domains: ['gymadvisor.s3.eu-west-2.amazonaws.com'],
  },
};

export default nextConfig;
