import {
  AnimatedNumber,
  Button,
  ByondUi,
  Knob,
  LabeledControls,
  LabeledList,
  ProgressBar,
  Section,
  Table,
} from 'tgui-core/components';
import { decodeHtmlEntities } from 'tgui-core/string';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const HelmConsole = () => {
  const { data } = useBackend();
  const { mapRef, isViewer } = data as any;
  return (
    <Window width={870} height={708}>
      <div className="CameraConsole__left">
        <Window.Content>
          {!isViewer && <ShipControlContent />}
          <ShipContent />
          <SharedContent />
        </Window.Content>
      </div>
      <div className="CameraConsole__right">
        <div className="CameraConsole__toolbar">
          {!!(data as any).docked && (
            <div className="NoticeBox">
              Ship docked to: {(data as any).docked}
            </div>
          )}
        </div>
        <ByondUi
          className="CameraConsole__map"
          params={{
            id: mapRef,
            type: 'map',
          }}
        />
      </div>
    </Window>
  );
};

export { HelmConsole };

const SharedContent = () => {
  const { act, data } = useBackend();
  const { isViewer, shipInfo = [], otherInfo = [] } = data as any;
  return (
    <>
      <Section
        title={
          <Button.Input
            content={decodeHtmlEntities(shipInfo.name)}
            currentValue={shipInfo.name}
            disabled={isViewer}
            onCommit={(_e, value) =>
              act('rename_ship', {
                newName: value,
              })
            }
          />
        }
        buttons={
          !isViewer && shipInfo.name === 'No Ship Connected' && (
            <Button
              icon="link"
              content="Connect Ship"
              onClick={() => act('connect_ship')}
            />
          )
        }
      >
        <LabeledList>
          <LabeledList.Item label="Class">{shipInfo.class}</LabeledList.Item>
          <LabeledList.Item label="Sensor Range">
            <ProgressBar
              value={shipInfo.sensor_range}
              minValue={1}
              maxValue={8}
            >
              <AnimatedNumber value={shipInfo.sensor_range} />
            </ProgressBar>
          </LabeledList.Item>
          {shipInfo.mass && (
            <LabeledList.Item label="Mass">
              {shipInfo.mass + 'tonnes'}
            </LabeledList.Item>
          )}
        </LabeledList>
      </Section>
      <Section title="Radar">
        <Table>
          <Table.Row bold>
            <Table.Cell>Name</Table.Cell>
            {!isViewer && <Table.Cell>Act</Table.Cell>}
          </Table.Row>
          {otherInfo.map((ship) => (
            <Table.Row key={ship.name}>
              <Table.Cell>{ship.name}</Table.Cell>
              {!isViewer && (
                <Table.Cell>
                  <Button
                    tooltip="Interact"
                    tooltipPosition="left"
                    icon="circle"
                    disabled={isViewer}
                    onClick={() =>
                      act('act_overmap', {
                        ship_to_act: ship.ref,
                      })
                    }
                  />
                </Table.Cell>
              )}
            </Table.Row>
          ))}
        </Table>
      </Section>
    </>
  );
};

const ShipContent = () => {
  const { data } = useBackend();
  const { speed, course, heading, eta, x, y } = data as any;
  return (
    <Section title="Velocity">
      <LabeledList>
        <LabeledList.Item label="Speed">
          <ProgressBar
            ranges={{
              good: [0, 4],
              average: [4, 7],
              bad: [7, Infinity],
            }}
            maxValue={10}
            value={speed}
          >
            <AnimatedNumber
              value={speed}
              format={(value) => value.toFixed(2)}
            />
            Gm/s
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Heading">
          <AnimatedNumber value={heading} />
        </LabeledList.Item>
        <LabeledList.Item label="Course">
          <AnimatedNumber value={course} />
        </LabeledList.Item>
        <LabeledList.Item label="Position">
          X<AnimatedNumber value={x} />
          /Y
          <AnimatedNumber value={y} />
        </LabeledList.Item>
        <LabeledList.Item label="ETA">
          <AnimatedNumber value={eta} />
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const ShipControlContent = () => {
  const { act, data } = useBackend();
  const {
    calibrating,
    aiControls,
    aiUser,
    burnDirection,
    burnPercentage,
    speed,
    estThrust,
    rotating,
  } = data as any;
  let flyable = !(data as any).docking && !(data as any).docked;

  const DIRECTIONS = {
    north: 1,
    south: 2,
    east: 4,
    west: 8,
    northeast: 1 + 4,
    northwest: 1 + 8,
    southeast: 2 + 4,
    southwest: 2 + 8,
    stop: -1,
  };
  return (
    <Section
      title="Navigation"
      buttons={
        <>
          <Button
            tooltip="Undock"
            tooltipPosition="left"
            icon="sign-out-alt"
            disabled={!(data as any).docked || (data as any).docking}
            onClick={() => act('undock')}
          />
          <Button
            tooltip="Dock in Empty Space"
            tooltipPosition="left"
            icon="sign-in-alt"
            disabled={!flyable || speed}
            onClick={() => act('dock_empty')}
          />
        </>
      }
    >
      <LabeledControls>
        <LabeledControls.Item label="Direction" width={'100%'}>
          <Table collapsing>
            <Table.Row height={1}>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-up"
                  style={{ transform: 'rotate(-45deg)' }}
                  color={burnDirection === DIRECTIONS.northwest && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.northwest,
                    })
                  }
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-up"
                  color={burnDirection === DIRECTIONS.north && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.north,
                    })
                  }
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-up"
                  style={{ transform: 'rotate(45deg)' }}
                  color={burnDirection === DIRECTIONS.northeast && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.northeast,
                    })
                  }
                />
              </Table.Cell>
            </Table.Row>
            <Table.Row height={1}>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-left"
                  color={burnDirection === DIRECTIONS.west && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.west,
                    })
                  }
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  tooltip={burnDirection === 0 ? 'Slow down' : 'Stop thrust'}
                  icon={
                    burnDirection === 0 || burnDirection === DIRECTIONS.stop
                      ? 'stop'
                      : 'pause'
                  }
                  color={burnDirection === DIRECTIONS.stop && 'good'}
                  disabled={!flyable || (burnDirection === 0 && !speed)}
                  onClick={() => act('stop')}
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-right"
                  color={burnDirection === DIRECTIONS.east && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.east,
                    })
                  }
                />
              </Table.Cell>
            </Table.Row>
            <Table.Row height={1}>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-down"
                  style={{ transform: 'rotate(45deg)' }}
                  color={burnDirection === DIRECTIONS.southwest && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.southwest,
                    })
                  }
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-down"
                  color={burnDirection === DIRECTIONS.south && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.south,
                    })
                  }
                />
              </Table.Cell>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-down"
                  style={{ transform: 'rotate(-45deg)' }}
                  color={burnDirection === DIRECTIONS.southeast && 'good'}
                  disabled={!flyable}
                  onClick={() =>
                    act('change_heading', {
                      dir: DIRECTIONS.southeast,
                    })
                  }
                />
              </Table.Cell>
            </Table.Row>
          </Table>
        </LabeledControls.Item>
        <LabeledControls.Item label="Throttle">
          <Knob
            value={burnPercentage}
            minValue={1}
            step={1}
            maxValue={100}
            size={2}
            unit="%"
            animated
            onDrag={(e, value) =>
              act('set_throttle', {
                throttle: value,
              })
            }
          />
        </LabeledControls.Item>
      </LabeledControls>
    </Section>
  );
};
