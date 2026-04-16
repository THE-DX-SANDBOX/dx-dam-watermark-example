import { defineConfig } from 'vitepress';

const repository = process.env.GITHUB_REPOSITORY || '';
const repoName = repository.includes('/') ? repository.split('/')[1] : '';
const base = process.env.NODE_ENV === 'production' && repoName ? `/${repoName}/` : '/';

export default defineConfig({
  title: 'DAM Demo Docs',
  description: 'Repository documentation for the DAM plugin template.',
  base,
  cleanUrls: true,
  ignoreDeadLinks: [
    /^https?:\/\/localhost/,
    /^(?:\.\/)?\.\.\//,
    /^(?:\.\/)?packages\//,
    /^(?:\.\/)?scripts\//,
    /^(?:\.\/)?\.env(?:\.example)?$/,
    /^(?:\.\/)?README$/,
    /^(?:\.\/)?START_HERE$/,
    /^\.\/DATABASE_SETUP$/,
  ],
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'Deployment', link: '/deployment-overview' },
      { text: 'Registration', link: '/plugin-registration' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'What This App Does', link: '/what-this-app-does' },
          { text: 'Repo Structure', link: '/repo-structure' },
        ],
      },
      {
        text: 'Architecture',
        items: [
          { text: 'System Architecture', link: '/architecture' },
          { text: 'Components', link: '/components' },
          { text: 'Runtime Flow', link: '/runtime-flow' },
        ],
      },
      {
        text: 'Operations',
        items: [
          { text: 'Deployment Overview', link: '/deployment-overview' },
          { text: 'Plugin Registration', link: '/plugin-registration' },
          { text: 'Customization Guide', link: '/customization-guide' },
          { text: 'Reference', link: '/reference' },
        ],
      },
      {
        text: 'Detailed Existing Docs',
        items: [
          { text: 'Development', link: '/DEVELOPMENT' },
          { text: 'Deployment Details', link: '/DEPLOYMENT' },
          { text: 'Portlet Deployment', link: '/PORTLET_DEPLOYMENT' },
          { text: 'Registration Guide', link: '/REGISTRATION' },
          { text: 'AI Rendition Integration', link: '/AI_RENDITION_INTEGRATION' },
        ],
      },
    ],
    socialLinks: repository ? [{ icon: 'github', link: `https://github.com/${repository}` }] : [],
    search: {
      provider: 'local',
    },
    outline: 'deep',
    docFooter: {
      prev: 'Previous page',
      next: 'Next page',
    },
  },
});