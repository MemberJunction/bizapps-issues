/**
 * BizApps Issues Server Bootstrap
 *
 * Server-side bootstrap package for the BizApps Issues Open App. Ensures all
 * entity subclasses, action subclasses, core service registrations, and GraphQL
 * resolvers are registered with the MJ class factory at MJAPI startup.
 */

// Import entity and action packages to trigger @RegisterClass decorators
import '@mj-biz-apps/issues-entities';
import '@mj-biz-apps/issues-actions';

// Core services
import '@mj-biz-apps/issues-core';

// Server-side entity subclasses — must come after issues-entities so
// @RegisterClass auto-increment gives these higher priority
import '@mj-biz-apps/issues-core-entities-server';

// Import generated GraphQL resolvers
import './generated/generated.js';

// Import generated class registrations manifest
import { CLASS_REGISTRATIONS } from './generated/class-registrations-manifest.js';

// Re-export the manifest for consumers
export { CLASS_REGISTRATIONS } from './generated/class-registrations-manifest.js';

import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

/** Absolute paths to the generated resolver files, for use with createMJServer() */
export const RESOLVER_PATHS = [resolve(__dirname, 'generated/generated.{js,ts}')];

/**
 * Bootstrap function called by DynamicPackageLoader during MJAPI startup.
 * The static imports above handle all registration; this function ensures the
 * module is fully evaluated.
 */
export function LoadBizAppsIssuesServer(): void {
  // Static imports above ensure all classes are registered.
  // This function exists as the startupExport entry point for DynamicPackageLoader.
  void CLASS_REGISTRATIONS;
}
