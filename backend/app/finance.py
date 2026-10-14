from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator

Amount = StrictInt


class Line(BaseModel):
    model_config = ConfigDict(extra="forbid")
    member_id: str
    contribution: Amount = Field(default=0, ge=0, le=10**12)
    penalty_paid: Amount = Field(default=0, ge=0, le=10**12)
    penalty_due: Amount = Field(default=0, ge=0, le=10**12)
    reason: str = Field(default="", max_length=300)


class Expense(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    label: str = Field(min_length=1, max_length=200)
    amount: Amount = Field(ge=0, le=10**12)


class Point(BaseModel):
    model_config = ConfigDict(extra="forbid")
    played_at: str
    rate: Amount = Field(ge=0, le=10**12)
    cancelled: bool = False
    lines: list[Line] = Field(max_length=1000)
    expenses: list[Expense] = Field(default_factory=list, max_length=1000)
    donations: list[Expense] = Field(default_factory=list, max_length=1000)

    @field_validator('played_at')
    @classmethod
    def valid_date(cls, value):
        datetime.fromisoformat(value)
        return value


def validate_point(point: Point, member_ids: set[str]):
    ids = [line.member_id for line in point.lines]
    if len(ids) != len(set(ids)) or not set(ids).issubset(member_ids):
        raise ValueError("Unknown or duplicate member")
    if len({x.id for x in point.expenses + point.donations}) != len(point.expenses + point.donations):
        raise ValueError("Duplicate movement")
    if point.cancelled and (any(x.contribution or x.penalty_paid or x.penalty_due for x in point.lines)
                            or point.expenses or point.donations):
        raise ValueError("Cancelled periods have contributions due but no payments, penalties or expenses")


def totals(points: list[dict], opening: dict | None = None):
    opening = opening or {}
    cash = opening.get("cash", 0)
    accounts = {key: dict(value) for key, value in opening.get("members", {}).items()}
    for point in points:
        if opening.get('start_date') and point['played_at'][:10] < opening['start_date']:
            continue
        for line in point["lines"]:
            account = accounts.setdefault(line["member_id"], {"contribution_balance": 0, "penalty_debt": 0})
            account["contribution_balance"] += line["contribution"] - point["rate"]
            account["penalty_debt"] += line["penalty_due"] - line["penalty_paid"]
            cash += line["contribution"] + line["penalty_paid"]
        cash += sum(x["amount"] for x in point["donations"])
        cash -= sum(x["amount"] for x in point["expenses"])
    return {"cash": cash, "members": accounts}
