import argparse
import zipfile
import io
import sys
from collections import defaultdict


def open_acmi_lines(path):
    """Yield lines from a TacView .acmi file (plain text or zipped)."""
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            # read first file in archive
            name = z.namelist()[0]
            with z.open(name) as f:
                for line in io.TextIOWrapper(f, encoding="utf-8", errors="ignore"):
                    yield line
    else:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                yield line


def parse_fields(line):
    fields = {}
    for token in line.split(','):
        token = token.strip()
        if not token:
            continue
        if '=' in token:
            key, value = token.split('=', 1)
            value = value.strip().strip('"')
            fields[key.strip()] = value
    return fields


def categorize_type(type_str):
    if not type_str:
        return 'ground'
    s = type_str.lower()
    if 'ship' in s or 'boat' in s or 'naval' in s:
        return 'ship'
    if 'air' in s or 'wing' in s or 'heli' in s:
        return 'air'
    return 'ground'


def update(stats, key):
    stats[key] = stats.get(key, 0) + 1


def parse_acmi(path):
    objects = {}
    pilot_stats = defaultdict(dict)
    group_stats = defaultdict(dict)

    for line in open_acmi_lines(path):
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        fields = parse_fields(line)
        if not fields:
            continue

        if 'Event' in fields:
            event = fields['Event']
            if event.startswith('TakeOff'):
                oid = fields.get('Object') or fields.get('PrimaryObject')
                obj = objects.get(oid)
                if obj:
                    p = obj.get('Pilot', 'Unknown')
                    g = obj.get('Group', 'Unknown')
                    update(pilot_stats[p], 'sorties')
                    update(group_stats[g], 'sorties')
            elif event == 'Kill':
                shooter_id = fields.get('PrimaryObject') or fields.get('Object')
                target_id = fields.get('SecondaryObject') or fields.get('Target')
                shooter = objects.get(shooter_id)
                target = objects.get(target_id, {})
                if shooter:
                    p = shooter.get('Pilot', 'Unknown')
                    g = shooter.get('Group', 'Unknown')
                    kill_type = categorize_type(target.get('Type'))
                    update(pilot_stats[p], f'kill_{kill_type}')
                    update(group_stats[g], f'kill_{kill_type}')
                    if shooter.get('Coalition') and shooter.get('Coalition') == target.get('Coalition'):
                        update(pilot_stats[p], 'friendly_fire')
                        update(group_stats[g], 'friendly_fire')
            elif event.startswith('Refuel'):
                oid = fields.get('Object')
                obj = objects.get(oid)
                if obj:
                    p = obj.get('Pilot', 'Unknown')
                    g = obj.get('Group', 'Unknown')
                    update(pilot_stats[p], 'refuels')
                    update(group_stats[g], 'refuels')
            elif event.startswith('CSAR') or event.startswith('Pickup'):
                oid = fields.get('Object')
                obj = objects.get(oid)
                if obj:
                    p = obj.get('Pilot', 'Unknown')
                    g = obj.get('Group', 'Unknown')
                    update(pilot_stats[p], 'csar_pickup')
                    update(group_stats[g], 'csar_pickup')
        else:
            oid = fields.get('Object') or fields.get('ID')
            if oid:
                objects[oid] = fields

    return pilot_stats, group_stats


def print_table(title, stats):
    headers = ['Sorties', 'KillAir', 'KillGround', 'KillShip', 'Refuel', 'CSAR', 'FF']
    print(title)
    print('{:20s} '.format('Name') + ' '.join('{:9s}'.format(h) for h in headers))
    print('-' * 20 + ' ' + ' '.join(['-'*9 for _ in headers]))
    for name, data in sorted(stats.items()):
        row = [
            data.get('sorties', 0),
            data.get('kill_air', 0),
            data.get('kill_ground', 0),
            data.get('kill_ship', 0),
            data.get('refuels', 0),
            data.get('csar_pickup', 0),
            data.get('friendly_fire', 0)
        ]
        print('{:20s} '.format(name) + ' '.join('{:9d}'.format(int(x)) for x in row))
    print()


def main():
    parser = argparse.ArgumentParser(description='TacView ACMI statistics')
    parser.add_argument('logfile', help='Path to .acmi log file')
    args = parser.parse_args()

    pilot_stats, group_stats = parse_acmi(args.logfile)

    print_table('Pilot stats', pilot_stats)
    print_table('Group stats', group_stats)


if __name__ == '__main__':
    main()
