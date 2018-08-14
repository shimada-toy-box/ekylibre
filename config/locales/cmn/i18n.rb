{ cmn: {
  i18n: {
    dir: 'ltr',
    iso2: 'zh-cn',
    ietf: 'zh-CN',
    name: '官話',
    plural: {
      keys: %i[one other],
      rule: ->(n) { n == 1 ? :one : :other }
    }
  },
  date: {
    order: %i[year month day]
  }
} }
