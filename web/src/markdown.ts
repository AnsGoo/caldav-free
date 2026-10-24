import DOMPurify from 'dompurify'
import { marked } from 'marked'
import TurndownService from 'turndown'
import { gfm } from 'turndown-plugin-gfm'

marked.setOptions({ gfm: true, breaks: true })

/** Renders Markdown to sanitized HTML for previews and exports. */
export function renderMarkdown(markdown: string): string {
  if (!markdown) return ''
  const html = marked.parse(markdown, { async: false }) as string
  return DOMPurify.sanitize(html, {
    USE_PROFILES: { html: true },
    ADD_ATTR: ['target', 'rel'],
  })
}

export function markdownToPlain(markdown: string): string {
  if (!markdown) return ''
  const wrapper = document.createElement('div')
  wrapper.innerHTML = renderMarkdown(markdown)
  wrapper.querySelectorAll('br').forEach((node) => node.replaceWith('\n'))
  wrapper
    .querySelectorAll('p, li, tr, h1, h2, h3, h4, h5, h6, blockquote, pre')
    .forEach((node) => node.append('\n'))
  return (wrapper.textContent || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

/** Converts legacy HTML notes and summaries into Markdown. */
export function htmlToMarkdown(html: string): string {
  if (!html) return ''
  if (!html.includes('<')) return html
  const doc = new DOMParser().parseFromString(html, 'text/html')
  doc.querySelectorAll('script, style, iframe, svg, noscript').forEach((node) => node.remove())
  const turndown = new TurndownService({
    headingStyle: 'atx',
    bulletListMarker: '-',
    codeBlockStyle: 'fenced',
  })
  turndown.use(gfm)
  turndown.addRule('checkbox', {
    filter: (node) => node.nodeName === 'INPUT' && (node as HTMLInputElement).type === 'checkbox',
    replacement: (_content, node) => ((node as HTMLInputElement).checked ? '[x] ' : '[ ] '),
  })
  return turndown
    .turndown(doc.body.innerHTML)
    .replace(/\u00a0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}
