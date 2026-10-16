export async function sportStep(page, number) {
  const label = ["1 · Options", "2 · Présents", "3 · Équipes", "4 · Match"][
    number - 1
  ];
  await page.getByRole("button", { name: label, exact: true }).click();
}
