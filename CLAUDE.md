# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gym Advisor is a Next.js 15 application for finding and managing gym listings. It features a public-facing frontend for browsing gyms and a protected admin panel for managing gyms, owners, categories, testimonials, and users.

## Development Commands

```bash
# Development
npm run dev              # Start dev server (http://localhost:3000)

# Production
npm run build            # Build for production
npm run start            # Start production server

# Linting
npm run lint             # Run ESLint

# Docker
npm run docker:build         # Build Docker image
npm run docker:run           # Run container with .env.local
npm run docker:compose:up    # Start with docker-compose
npm run docker:compose:down  # Stop docker-compose
```

## Architecture Overview

### Application Structure

The app uses Next.js 15 App Router with two distinct areas:

1. **Public Frontend** (`/`, `/browse`, `/gym/[slug]`, `/about-us`, `/why-register`, `/signup`)
   - User-facing gym browsing and discovery
   - Dynamic gym detail pages with slug-based routing
   - Header/Footer layout (conditionally rendered based on route)

2. **Admin Panel** (`/admin/*` routes)
   - Protected by middleware requiring `adminAuthToken` cookie
   - Separate layout with Sidebar and Header components
   - Manages gyms, owners, categories, testimonials, users, and dashboard

3. **Gym Owner Portal** (`/gym-owner/*` routes)
   - Protected area for gym owners to manage their listings
   - Routes: `/gym-owner/dashboard`, `/gym-owner/gyms`, `/gym-owner/add-gym`, `/gym-owner/claim-gym`, `/gym-owner/account`
   - Uses Firebase authentication for gym owners
   - Separate layout with `OwnerLayout.jsx` component

### Authentication & Routing

- **Middleware** (`src/middleware.js`): Protects all `/admin/*` routes
  - Redirects unauthenticated users to `/admin-login`
  - Redirects authenticated users away from login page to `/admin/dashboard`
  - Uses `adminAuthToken` cookie for session management

- **Auth Flow**: Two separate authentication systems
  - **Admin**: Cookie-based with JWT (`adminAuthToken` cookie, 7-day expiration)
    - All admin API calls include `Authorization: Bearer <token>` header
    - 401/403 responses trigger automatic logout and redirect
  - **Gym Owners**: Firebase authentication
    - Uses Firebase SDK for sign-in/sign-up (`src/components/Auth/firebase.js`)
    - Supports email/password authentication
    - Owner registration at `/owner-sign-up`

### State Management (Redux Toolkit)

Store location: `src/store/index.js`

**Slices:**
- `auth`: Admin authentication state, login/logout actions
- `gyms`: Gym listings, CRUD operations, status toggles
- `testimonials`: Testimonial management
- `owners`: Gym owner data and gym owner portal operations
- `categories`: Category management
- `dashboard`: Dashboard statistics
- `frontend`: Public-facing gym detail pages (slug-based fetching)
- `location`: Location/geography data
- `user`: User management
- `SaveSliceGym`: Saved gym functionality

**API Integration Pattern:**
- All slices use `createAsyncThunk` for API calls
- Auth token retrieved from cookies via `js-cookie`
- Headers include both `Authorization: Bearer <token>` and `X-API-KEY` (if needed)
- API base URL from `process.env.NEXT_PUBLIC_API_URL`
- API key from `process.env.NEXT_PUBLIC_API_KEY`

**Interceptor Pattern:**
- `src/store/Interceptors.js` provides `fetchWithAuth()` helper
- Automatically handles 401/403 by removing auth cookie and redirecting to login
- Use this for any auth-required fetch operations outside Redux slices

### Component Organization

```
src/components/
├── admin/               # Admin panel components
│   ├── Sidebar.js
│   ├── Header.js
│   ├── DashboardClient.js
│   ├── MediaUpload.js   # AWS S3 image upload
│   ├── MultipleMedia.js # Multiple file uploads
│   ├── RichTextEditor.js # TipTap editor
│   └── category/
├── Auth/                # Authentication components
│   ├── firebase.js      # Firebase configuration
│   ├── GymOwnerRegister.jsx
│   ├── GymUserRegister.jsx
│   ├── LoginModalForBoth.jsx
│   ├── ForgotPassword.jsx
│   └── RegisterAskModal.jsx
├── gym-owner/           # Gym owner portal components
│   ├── OwnerLayout.jsx  # Layout for owner pages
│   ├── ViewGymModal.jsx
│   ├── claim/           # Gym claiming components
│   │   ├── GymClaimDrawer.jsx
│   │   └── ClaimUpdateDrawer.jsx
│   └── gyms/            # Gym management
│       └── GymAddByOwner.jsx
├── Utils/               # Shared utility components
└── user/                # Public frontend components
    ├── Layout/
    │   ├── LayoutWrapper.jsx  # Conditional Header/Footer
    │   ├── Header.jsx
    │   └── Footer.jsx
    ├── Home/            # Homepage sections
    ├── Browse/
    └── Gym/
        ├── DetailPage.jsx
        └── DynamicMap.jsx  # Leaflet maps
```

### Layout System

- **Root Layout** (`src/app/layout.js`):
  - Wraps everything with `LayoutWrapper`
  - Loads custom Avenir font from `/public/fonts/`
  - Metadata and global styles

- **LayoutWrapper** (`src/components/user/Layout/LayoutWrapper.jsx`):
  - Wraps children with Redux Provider
  - Conditionally shows Header/Footer (hidden on `/` homepage and `/admin/*` routes)
  - Uses `Suspense` for pathname detection

- **Admin Layout** (`src/app/admin/layout.js`):
  - Provides Sidebar + Header for all admin pages
  - Mobile-responsive sidebar toggle
  - Left margin adjustment for fixed sidebar

### Media Upload (AWS S3)

`MediaUpload.js` and `MultipleMedia.js` handle direct S3 uploads:
- Configured via props: `bucketName`, `region`, `accessKeyId`, `secretAccessKey`
- Validates file type, size, and optionally dimensions
- Generates unique filenames with timestamp
- Returns S3 URL on success via `onSuccess` callback
- Image domain whitelisted in `next.config.mjs`: `gymadvisor.s3.eu-west-2.amazonaws.com`

### Styling

- **Tailwind CSS** with custom configuration:
  - Primary color: `#0DBABA` (accessible via `text-primary`, `bg-primary`, etc.)
  - Custom fonts: `lemmon_milk`, `AvenirLTStd`, `lemmon_milk_bold`
  - Font loaded via `next/font/local` in layout

- **Global styles**: `src/app/globals.css`

### Dynamic Routes

- `/gym/[slug]` - Fetches gym by slug using `fetchPublicGymBySlug` thunk from `frontendSlice`
- Uses Next.js dynamic routing with `params.slug`

## Important Patterns

### Adding New Admin Features

1. Create Redux slice in `src/store/slices/` with async thunks
2. Add reducer to `src/store/index.js`
3. Create page component in `src/app/admin/[feature]/page.js`
4. Update Sidebar navigation in `src/components/admin/Sidebar.js`
5. Ensure API calls use `getAuthHeaders()` helper pattern (see `gymSlice.js`)

### Environment Variables Required

All environment variables should be prefixed with `NEXT_PUBLIC_` for client-side access:

```
NEXT_PUBLIC_API_URL              # Backend API base URL
NEXT_PUBLIC_API_KEY              # API key for backend
NEXT_PUBLIC_BUCKET_NAME          # AWS S3 bucket name (default: gymadvisor)
NEXT_PUBLIC_BUCKET_REGION        # AWS S3 region (default: eu-west-2)
NEXT_PUBLIC_RECAPTCHA_SITE_KEY   # Google reCAPTCHA site key
```

Note: AWS credentials for S3 uploads are provided via IAM role in production, not environment variables.

### API Response Format

Expected backend response structure:
```json
{
  "status": "success" | "error",
  "message": "...",
  "data": { ... }
}
```

All thunks check `result.status === 'success'` before treating as successful.

## Technology Stack

- **Framework**: Next.js 15 (App Router)
- **React**: v19
- **State Management**: Redux Toolkit with `@reduxjs/toolkit` and `react-redux`
- **Styling**: Tailwind CSS
- **Rich Text**: TipTap (`@tiptap/react`, `@tiptap/starter-kit`)
- **Maps**: Leaflet (`leaflet`, `react-leaflet`)
- **File Upload**: AWS SDK v2 (`aws-sdk`)
- **HTTP Client**: Native `fetch` API (axios also available)
- **Authentication**: Firebase (gym owners), Cookie-based JWT (admin)
- **Animations**: Framer Motion
- **Charts**: Chart.js with `react-chartjs-2`
- **Icons**: Heroicons, Lucide React
- **Carousel**: React Slick
- **Toasts**: Sonner (`sonner`)
- **Select**: React Select (`react-select`)
- **Containerization**: Docker with multi-stage builds

## Notes

- The codebase contains commented-out legacy code in several files - avoid uncommenting without understanding current implementation
- Cookie name `adminAuthToken` must match between `middleware.js`, `authSlice.js`, and `Interceptors.js`
- Admin area completely bypasses public layout (no Header/Footer from user components)
- Gym status toggling uses the `updateGym` thunk with a wrapper `toggleGymStatus` thunk
- Public API endpoints (like `fetchPublicGymBySlug`) don't require auth token
- Gym owners use Firebase auth, separate from admin cookie-based auth
- The gym owner portal allows owners to claim existing gyms or add new ones
- Docker builds use standalone output mode for optimized production images
- Image domains whitelisted in `next.config.mjs`: `gymadvisor.s3.eu-west-2.amazonaws.com`