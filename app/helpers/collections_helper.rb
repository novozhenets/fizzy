module CollectionsHelper
  def collection_auto_close_options
    [
      [ "30 days", 30.days ],
      [ "60 days", 60.days ],
      [ "90 days", 90.days ],
      [ "6 months", 180.days ],
      [ "1 year", 365.days ],
      [ "Never", nil ]
    ]
  end
end
