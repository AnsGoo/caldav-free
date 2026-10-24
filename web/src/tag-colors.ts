export const TAG_COLORS = [
  '#4772fa',
  '#e5484d',
  '#f76b15',
  '#f5b301',
  '#30a46c',
  '#12a594',
  '#00a2c7',
  '#6e56cf',
  '#d6409f',
  '#8e4ec6',
  '#64748b',
  '#ab6400',
]

export function tagColor(name: string, explicit?: string) {
  if (explicit && /^#[0-9a-fA-F]{6}$/.test(explicit)) return explicit
  let hash = 0
  for (let index = 0; index < name.length; index += 1) {
    hash = (hash * 31 + name.charCodeAt(index)) >>> 0
  }
  return TAG_COLORS[hash % TAG_COLORS.length]
}

export function tagTint(color: string) {
  return `color-mix(in srgb, ${color} 15%, transparent)`
}
