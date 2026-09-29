data:extend({
  {
    type = "mod-data",
    name = "quidquid-factory-search",
    data_type = "quidquid.action",
    data = {
      contract_version = 4,
      types = { "item", "fluid", "recipe", "resource" },
      -- Factory Search's own key, so the wording follows its translations.
      label = { "shortcut-name.search-factory" },
      hint = { "quidquid-factory-search.action-hint" },
      input_name = "quidquid-factory-search",
      interface = "quidquid-factory-search",
    },
  },
})
