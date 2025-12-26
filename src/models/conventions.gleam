pub type TierPrices {
  TierPrices(
    standard: Int,
    sponsor: Int,
    subsidised: Int,
    double_subsidised: Int,
  )
}

pub type Convention {
  Convention(id: String, name: String, prices: TierPrices)
}

pub const current_convention = Convention(
  id: "kad2026",
  name: "Kadcon 2026",
  prices: TierPrices(
    standard: 190,
    sponsor: 280,
    subsidised: 95,
    double_subsidised: 0,
  ),
)

pub const past_conventions: List(Convention) = [
  Convention(
    id: "kad2025",
    name: "Kadcon 2025",
    prices: TierPrices(
      standard: 0,
      sponsor: 0,
      subsidised: 0,
      double_subsidised: 0,
    ),
  ),
]
