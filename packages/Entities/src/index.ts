export * from './generated/entity_subclasses'

/**
 * Forces the generated entity subclasses to be loaded. Because the entities
 * are not directly referenced anywhere else, bundlers (webpack) tree-shake
 * them out unless this function is imported and called. Import and call it
 * from your bootstrap to guarantee the @RegisterClass decorators fire.
 *
 * @export
 * @returns {void}
 */
export function LoadGeneratedEntities(): void {
}
