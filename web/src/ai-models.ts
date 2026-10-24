export interface AIModelProfile {
  recommended: boolean
  tools: boolean
  vision: boolean
  reasoning: boolean
  light: boolean
  nonChat: boolean
}

const nonChatPattern = /embedding|embed-|whisper|tts|dall-e|moderation|rerank|transcribe|speech|audio|image-|stable-diffusion/i
const toolsPattern = /gpt-4o|gpt-4\.1|gpt-5|gpt-3\.5-turbo|^o[134]|deepseek-chat|qwen|glm-4|moonshot|llama-3\.[13]|mistral|command-r|sonnet|opus|gemini|kimi/i
const visionPattern = /gpt-4o|gpt-4\.1|gpt-5|vision|vl|gemini|claude|omni/i
const reasoningPattern = /^o[134]|reasoner|reasoning|qwq|thinking|deepseek-r1/i
const lightPattern = /mini|flash|turbo|small|7b|8b|air/i

export function modelProfile(id: string): AIModelProfile {
  const name = id.toLowerCase()
  const nonChat = nonChatPattern.test(name)
  const tools = !nonChat && toolsPattern.test(name)
  return {
    recommended: !nonChat && (tools || /chat|instruct|plus|max|pro|reasoner/i.test(name)),
    tools,
    vision: !nonChat && visionPattern.test(name),
    reasoning: !nonChat && reasoningPattern.test(name),
    light: !nonChat && lightPattern.test(name),
    nonChat,
  }
}

export function modelCapabilityLabels(id: string) {
  const profile = modelProfile(id)
  const labels: string[] = []
  if (profile.tools) labels.push('工具调用')
  if (profile.vision) labels.push('视觉')
  if (profile.reasoning) labels.push('推理')
  if (profile.light) labels.push('轻量')
  if (profile.nonChat) labels.push('可能不是对话模型')
  return labels
}

export function modelOptionLabel(id: string) {
  return modelProfile(id).recommended ? `★ ${id}` : id
}

export function sortModels(models: string[]) {
  return [...new Set(models)].sort((left, right) => {
    const a = modelProfile(left)
    const b = modelProfile(right)
    if (a.recommended !== b.recommended) return a.recommended ? -1 : 1
    if (a.nonChat !== b.nonChat) return a.nonChat ? 1 : -1
    return left.localeCompare(right)
  })
}
