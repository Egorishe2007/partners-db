"""Очистка исходных файлов и подготовка данных к импорту в базу."""

import csv
import os
import re

DATA_DIR = "data"
PARTNERS_SOURCE = os.path.join(DATA_DIR, "import_partners.csv")
SALES_SOURCE = os.path.join(DATA_DIR, "import_sales.txt")
PARTNER_TARGET = os.path.join(DATA_DIR, "clean_partner.csv")
PRODUCT_TARGET = os.path.join(DATA_DIR, "clean_product.csv")
DELIVERY_TARGET = os.path.join(DATA_DIR, "clean_delivery.csv")
REJECTED_TARGET = os.path.join(DATA_DIR, "rejected_rows.csv")

PARTNER_COLUMNS = ("partner_id", "company_name", "inn", "contact_email",
                   "phone", "rating")
PRODUCT_COLUMNS = ("product_id", "product_name")
DELIVERY_COLUMNS = ("delivery_id", "partner_id", "product_id",
                    "delivery_date", "quantity", "total_amount")
REJECTED_COLUMNS = ("file", "line", "reason", "row")

INN_PATTERN = re.compile(r"^(\d{10}|\d{12})$")
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")
ISO_DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
LOCAL_DATE_PATTERN = re.compile(r"^(\d{2})\.(\d{2})\.(\d{4})$")
AMOUNT_PATTERN = re.compile(r"^\d+([.,]\d{1,2})?$")


def squeeze_spaces(value: str) -> str:
    """Убрать пробелы по краям и повторяющиеся пробелы внутри строки."""
    return " ".join(value.split())


def clean_phone(value: str) -> str:
    """Привести телефон к виду +7XXXXXXXXXX; нераспознанный станет NULL."""
    digits = re.sub(r"\D", "", value)
    if not digits:
        return ""
    if len(digits) == 10:
        digits = "7" + digits
    if len(digits) == 11 and digits[0] == "8":
        digits = "7" + digits[1:]
    if len(digits) != 11:
        return ""
    return "+" + digits


def clean_rating(value: str) -> str:
    """Привести рейтинг к числу с точкой; пустое значение станет NULL."""
    return value.strip().replace(",", ".")


def clean_date(value: str) -> str:
    """Привести дату к формату ГГГГ-ММ-ДД; иначе вернуть пустую строку."""
    value = value.strip()
    if ISO_DATE_PATTERN.match(value):
        return value
    match = LOCAL_DATE_PATTERN.match(value)
    if match is None:
        return ""
    day, month, year = match.groups()
    return f"{year}-{month}-{day}"


def clean_amount(value: str) -> str:
    """Привести сумму к виду 12345.67; иначе вернуть пустую строку."""
    value = value.strip().replace(",", ".")
    if not AMOUNT_PATTERN.match(value):
        return ""
    return value


def reject(rejected: list, source: str, line: int, reason: str, row: dict):
    """Отложить строку, которую нельзя импортировать, и записать причину."""
    values = "; ".join(f"{key}={value}" for key, value in row.items())
    rejected.append({"file": os.path.basename(source), "line": line,
                     "reason": reason, "row": values})


def get_product_id(products: dict, product_name: str) -> int:
    """Вернуть номер продукта в справочнике, добавив новый при первой встрече."""
    if product_name not in products:
        products[product_name] = len(products) + 1
    return products[product_name]


def read_partners(rejected: list) -> list:
    """Прочитать файл партнеров и вернуть очищенные строки."""
    partners = []
    seen_inn = set()
    seen_email = set()
    with open(PARTNERS_SOURCE, encoding="utf-8", newline="") as source:
        for line, row in enumerate(csv.DictReader(source), start=2):
            company_name = squeeze_spaces(row["company_name"])
            inn = row["inn"].strip()
            email = row["contact_email"].strip().lower()
            if not company_name:
                reject(rejected, PARTNERS_SOURCE, line,
                       "пустое название компании", row)
                continue
            if not INN_PATTERN.match(inn):
                reject(rejected, PARTNERS_SOURCE, line,
                       "ИНН не из 10 или 12 цифр", row)
                continue
            if not EMAIL_PATTERN.match(email):
                reject(rejected, PARTNERS_SOURCE, line,
                       "неверный формат электронной почты", row)
                continue
            if inn in seen_inn or email in seen_email:
                reject(rejected, PARTNERS_SOURCE, line,
                       "дубликат по ИНН или почте", row)
                continue
            seen_inn.add(inn)
            seen_email.add(email)
            partners.append({"partner_id": row["partner_id"].strip(),
                             "company_name": company_name,
                             "inn": inn,
                             "contact_email": email,
                             "phone": clean_phone(row["phone"]),
                             "rating": clean_rating(row["rating"])})
    return partners


def read_deliveries(partner_ids: set, products: dict,
                    rejected: list) -> list:
    """Прочитать файл отгрузок и вернуть очищенные строки."""
    deliveries = []
    seen_ids = set()
    with open(SALES_SOURCE, encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source, delimiter="\t")
        for line, row in enumerate(reader, start=2):
            delivery_id = row["sale_id"].strip()
            partner_id = row["partner_id"].strip()
            product_name = squeeze_spaces(row["product_name"])
            delivery_date = clean_date(row["sale_date"])
            quantity = row["quantity"].strip()
            total_amount = clean_amount(row["total_amount"])
            if delivery_id in seen_ids:
                reject(rejected, SALES_SOURCE, line,
                       "дубликат номера отгрузки", row)
                continue
            if partner_id not in partner_ids:
                reject(rejected, SALES_SOURCE, line,
                       f"партнера {partner_id} нет в справочнике", row)
                continue
            if not product_name:
                reject(rejected, SALES_SOURCE, line,
                       "пустое название продукции", row)
                continue
            if not delivery_date:
                reject(rejected, SALES_SOURCE, line,
                       "не распознана дата отгрузки", row)
                continue
            if not quantity.isdigit() or int(quantity) <= 0:
                reject(rejected, SALES_SOURCE, line,
                       "объем не является целым числом больше нуля", row)
                continue
            if not total_amount:
                reject(rejected, SALES_SOURCE, line,
                       "неверный формат суммы поставки", row)
                continue
            seen_ids.add(delivery_id)
            deliveries.append({"delivery_id": delivery_id,
                               "partner_id": partner_id,
                               "product_id": get_product_id(products,
                                                            product_name),
                               "delivery_date": delivery_date,
                               "quantity": quantity,
                               "total_amount": total_amount})
    return deliveries


def write_csv(path: str, columns: tuple, rows: list):
    """Записать подготовленные строки в CSV для команды COPY."""
    with open(path, "w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def main():
    rejected = []
    products = {}
    partners = read_partners(rejected)
    partner_ids = {partner["partner_id"] for partner in partners}
    deliveries = read_deliveries(partner_ids, products, rejected)
    product_rows = [{"product_id": number, "product_name": name}
                    for name, number in products.items()]
    write_csv(PARTNER_TARGET, PARTNER_COLUMNS, partners)
    write_csv(PRODUCT_TARGET, PRODUCT_COLUMNS, product_rows)
    write_csv(DELIVERY_TARGET, DELIVERY_COLUMNS, deliveries)
    write_csv(REJECTED_TARGET, REJECTED_COLUMNS, rejected)
    print(f"Партнеры: подготовлено строк {len(partners)}")
    print(f"Продукция: подготовлено строк {len(product_rows)}")
    print(f"Отгрузки: подготовлено строк {len(deliveries)}")
    print(f"Отклонено строк: {len(rejected)}")
    for row in rejected:
        print(f"  {row['file']}, строка {row['line']}: {row['reason']}")


if __name__ == "__main__":
    main()
