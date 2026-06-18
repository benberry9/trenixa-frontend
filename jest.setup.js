import '@testing-library/jest-dom';

// Mock next/image
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props) => {
    // eslint-disable-next-line @next/next/no-img-element, jsx-a11y/alt-text
    return <img {...props} />;
  },
}));

// Mock next/navigation
jest.mock('next/navigation', () => ({
  useRouter: () => ({
    push: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
    prefetch: jest.fn(),
  }),
  usePathname: () => '/test-path',
}));

// Mock sonner
jest.mock('sonner', () => ({
  toast: {
    success: jest.fn(),
    error: jest.fn(),
    info: jest.fn(),
    warning: jest.fn(),
  },
}));

// Mock AWS SDK
jest.mock('aws-sdk', () => {
  const mockUpload = jest.fn().mockReturnValue({
    on: jest.fn().mockReturnThis(),
    send: jest.fn((callback) => callback(null, { Location: 'https://test-bucket.s3.amazonaws.com/test-image.jpg' })),
  });

  return {
    config: {
      update: jest.fn(),
    },
    S3: jest.fn().mockImplementation(() => ({
      upload: mockUpload,
    })),
  };
});

// Mock URL.createObjectURL
global.URL.createObjectURL = jest.fn(() => 'blob:test-url');
global.URL.revokeObjectURL = jest.fn();

// Mock Image constructor for dimension validation
class MockImage {
  constructor() {
    setTimeout(() => {
      this.width = 500;
      this.height = 500;
      if (this.onload) this.onload();
    }, 0);
  }
}
global.Image = MockImage;
